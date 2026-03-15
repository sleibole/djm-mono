# Deployment Guide — Fly.io

This guide covers deploying the core and songs apps to Fly.io with LiteFS (SQLite replication), Tigris (S3-compatible object storage), and AWS SES (transactional email).

## Prerequisites

- [flyctl](https://fly.io/docs/flyctl/install/) installed and authenticated (`fly auth login`)
- An AWS account with SES production access (US East / N. Virginia)
- A domain name (`djmagic.io`) with DNS access

## Architecture

```
Fly proxy :443 → LiteFS proxy :8080 (write forwarding) → Puma :3000
```

| Fly App | Source | Database | Storage | Background Jobs |
|---------|--------|----------|---------|-----------------|
| `djm-core` | `core/` | SQLite via LiteFS | Local (no file uploads) | Solid Queue in Puma (primary only) |
| `djm-songs-1` | `songs/` | SQLite via LiteFS | Tigris (CSV files) | Solid Queue in Puma (primary only) |

LiteFS replicates the application databases across instances. Per-catalog song databases are ephemeral artifacts rebuilt from CSVs on each instance startup — they are not replicated.

Solid Queue only runs on the primary node. The `bin/fly-entrypoint` script detects the node role via LiteFS's `.primary` file and sets `SOLID_QUEUE_IN_PUMA=true` accordingly.

---

## First-Time Setup

### 1. Create Fly Apps

```bash
fly apps create djm-core
fly apps create djm-songs-1
```

### 2. Create Volumes

Each app needs a persistent volume for LiteFS internal data.

```bash
fly volumes create litefs --size 1 -a djm-core -r ord
fly volumes create litefs --size 1 -a djm-songs-1 -r ord
```

### 3. Attach Consul

LiteFS uses Consul for distributed lease management (primary election).

```bash
fly consul attach -a djm-core
fly consul attach -a djm-songs-1
```

### 4. Create Tigris Storage Bucket

The songs app stores CSV uploads in Tigris. This command creates a bucket and automatically sets the required env vars (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ENDPOINT_URL_S3`, `BUCKET_NAME`) on the app.

```bash
fly storage create -a djm-songs-1
```

### 5. Set Secrets

See the [Environment Variables](#environment-variables) section below for details on each variable.

```bash
# Generate a strong JWT secret (use the SAME value for both apps)
JWT_SECRET=$(openssl rand -hex 32)

fly secrets set DJM_JWT_SECRET="$JWT_SECRET" -a djm-core
fly secrets set DJM_JWT_SECRET="$JWT_SECRET" -a djm-songs-1

# Core app
fly secrets set RAILS_MASTER_KEY="$(cat core/config/master.key)" -a djm-core
fly secrets set SONGS_APP_URL="https://djm-songs-1.fly.dev" -a djm-core
fly secrets set SONGS_SHARD_1_URL="https://djm-songs-1.fly.dev" -a djm-core
fly secrets set CORE_APP_URL="https://djm-core.fly.dev" -a djm-core

# Core app — SES SMTP
fly secrets set SES_SMTP_USERNAME="<your-ses-smtp-username>" -a djm-core
fly secrets set SES_SMTP_PASSWORD="<your-ses-smtp-password>" -a djm-core

# Songs app
fly secrets set RAILS_MASTER_KEY="$(cat songs/config/master.key)" -a djm-songs-1
fly secrets set CORE_APP_URL="https://djm-core.fly.dev" -a djm-songs-1
```

### 6. AWS SES — Verify Domain

1. Open the [SES console](https://console.aws.amazon.com/ses/) in US East (N. Virginia)
2. Go to **Identities → Create identity → Domain → djmagic.io**
3. Add the DKIM CNAME records SES provides to your DNS
4. Wait for verification (usually minutes, can take up to 72 hours)
5. Generate SMTP credentials: **SMTP settings → Create SMTP credentials**

### 7. Deploy

```bash
bin/fly-deploy core
bin/fly-deploy songs
```

---

## Environment Variables

### Both Apps

| Variable | Set via | Description |
|----------|---------|-------------|
| `RAILS_MASTER_KEY` | `fly secrets` | Decrypts `credentials.yml.enc`. Value from `config/master.key` in each app. |
| `DJM_JWT_SECRET` | `fly secrets` | HS256 shared secret for JWT signing between core and songs. **Must be identical on both apps.** |
| `RUBY_YJIT_ENABLE` | `fly.toml` [env] | Set to `"1"` to enable YJIT. Already configured in fly.toml. |
| `SOLID_QUEUE_IN_PUMA` | `bin/fly-entrypoint` | Auto-set to `true` on the primary node. Do not set manually. |
| `RAILS_LOG_LEVEL` | optional | Defaults to `info`. Set to `debug` for verbose logging. |

### Core App (`djm-core`)

| Variable | Set via | Description |
|----------|---------|-------------|
| `SONGS_APP_URL` | `fly secrets` | Default/fallback URL for the songs API (e.g. `https://djm-songs-1.fly.dev`). |
| `SONGS_SHARD_1_URL` | `fly secrets` | Songs shard 1 URL. Falls back to `SONGS_APP_URL` if not set. |
| `SONGS_SHARD_N_URL` | `fly secrets` | Additional shard URLs (e.g. `SONGS_SHARD_2_URL`). Add as shards are created. |
| `CORE_APP_URL` | `fly secrets` | Public URL of the core app. Used for generating profile/show URLs. |
| `SES_SMTP_USERNAME` | `fly secrets` | AWS SES SMTP username (from SES console, not IAM access key). |
| `SES_SMTP_PASSWORD` | `fly secrets` | AWS SES SMTP password. |
| `SES_SMTP_ADDRESS` | `fly secrets` | SES SMTP endpoint. Defaults to `email-smtp.us-east-1.amazonaws.com` if not set. |
| `TURNSTILE_SITE_KEY` | `fly secrets` | Cloudflare Turnstile site key. Optional — captcha is skipped when not set. |
| `TURNSTILE_SECRET_KEY` | `fly secrets` | Cloudflare Turnstile secret key. Optional — captcha is skipped when not set. |

### Songs App (`djm-songs-1`)

| Variable | Set via | Description |
|----------|---------|-------------|
| `CORE_APP_URL` | `fly secrets` | URL of the core app (used for CORS origin). |
| `AWS_ACCESS_KEY_ID` | `fly storage create` | Tigris access key. Auto-set when Tigris bucket is created. |
| `AWS_SECRET_ACCESS_KEY` | `fly storage create` | Tigris secret key. Auto-set. |
| `AWS_ENDPOINT_URL_S3` | `fly storage create` | Tigris S3 endpoint. Auto-set. |
| `BUCKET_NAME` | `fly storage create` | Tigris bucket name. Auto-set. |

### Fly.io-Provided Variables (automatic)

These are set by Fly.io on every machine and used by LiteFS config:

| Variable | Description |
|----------|-------------|
| `FLY_APP_NAME` | App name (e.g. `djm-core`) |
| `FLY_REGION` | Region of this machine (e.g. `ord`) |
| `FLY_ALLOC_ID` | Unique allocation ID for this machine |
| `PRIMARY_REGION` | Primary region from `fly.toml` |
| `FLY_CONSUL_URL` | Consul URL for LiteFS lease management |

---

## Deploying

From the monorepo root:

```bash
# Deploy core app
bin/fly-deploy core

# Deploy songs app
bin/fly-deploy songs
```

This runs `fly deploy -c fly.core.toml` or `fly deploy -c fly.songs.toml` respectively. Fly builds the Docker image using the monorepo root as the build context, which includes the `shared/djm_jwt` gem.

---

## Custom Domain

When ready to use `djmagic.io` instead of `*.fly.dev`:

```bash
fly certs add djmagic.io -a djm-core
```

Fly will provide IP addresses or a CNAME target. Add the appropriate DNS records. The `config.hosts` in `production.rb` already allows `djmagic.io` and `*.djmagic.io`.

Update the `CORE_APP_URL` and `SONGS_APP_URL` secrets if you switch to custom domains:

```bash
fly secrets set CORE_APP_URL="https://djmagic.io" -a djm-core
fly secrets set CORE_APP_URL="https://djmagic.io" -a djm-songs-1
fly secrets set SONGS_APP_URL="https://songs1.djmagic.io" -a djm-core
fly secrets set SONGS_SHARD_1_URL="https://songs1.djmagic.io" -a djm-core
```

---

## Operations

### SSH / Rails Console

```bash
fly ssh console -a djm-core
fly ssh console -a djm-songs-1

# Or use the configured console command
fly ssh console -a djm-core -C "/rails/bin/rails console"
```

### Logs

```bash
fly logs -a djm-core
fly logs -a djm-songs-1
```

### Transactional Email (SES)

| Setting | Value |
|---------|-------|
| Sender | `DJMagic <noreply@djmagic.io>` |
| SES region | `us-east-1` |
| Configuration set | `djmagic-app` |
| Required secrets | `SES_SMTP_USERNAME`, `SES_SMTP_PASSWORD` |

Every outbound email includes the `X-SES-CONFIGURATION-SET: djmagic-app` header, which routes delivery/bounce/complaint events to the SNS topic configured in the SES console.

**Verifying delivery after deploy:**

```bash
# Via rake task
fly ssh console -a djm-core -C "/rails/bin/rails email:test[you@example.com]"

# Or via Rails runner
fly ssh console -a djm-core -C "/rails/bin/rails runner 'SystemMailer.ses_test_email(to: \"you@example.com\").deliver_now'"
```

Replace `you@example.com` with a real address you can check. In development, mail is routed to `localhost:1025` (use [Mailpit](https://github.com/axllent/mailpit) or similar).

### SNS Webhook (SES Events)

The app exposes `POST /webhooks/sns/ses` to receive SES delivery, bounce, and complaint notifications via SNS.

**How it works:**

1. SES publishes events to an SNS topic (configured via the `djmagic-app` configuration set).
2. SNS sends HTTPS POST requests to the webhook endpoint.
3. The app auto-confirms the SNS subscription on first request.
4. Delivery events update `last_delivered_at` on the matching user.
5. Bounce events mark the user as `email_status: "bounced"` and record the bounce reason.
6. Complaint events mark the user as `email_status: "complained"` and record the feedback type.

Users with `email_status` other than `"active"` can be filtered out via `User.emailable` to avoid sending to bad addresses.

**Subscribing the SNS topic (one-time setup):**

```bash
aws sns subscribe \
  --topic-arn "arn:aws:sns:us-east-1:ACCOUNT_ID:TOPIC_NAME" \
  --protocol https \
  --notification-endpoint "https://djmagic.io/webhooks/sns/ses"
```

Replace `ACCOUNT_ID` and `TOPIC_NAME` with your actual values. The app will automatically confirm the subscription when SNS sends the confirmation request.

You can also subscribe via the AWS SES console: **Configuration sets → djmagic-app → Event destinations → edit the SNS destination** and ensure the subscription is active.

### Scaling (Adding Replicas)

LiteFS is already configured for multi-node operation. To add a read replica in another region:

```bash
fly machine clone --select --region lhr -a djm-core
```

The new machine will sync its LiteFS database from the primary. Solid Queue will not run on the replica (the `fly-entrypoint` script handles this automatically).

### Database Backup

For now, databases are persisted on the LiteFS volume. For additional safety, consider configuring LiteFS backup to S3/Tigris (see [LiteFS backup docs](https://fly.io/docs/litefs/backup/)).

---

## File Layout

```
djm-mono/
├── Dockerfile.core          # Fly.io Dockerfile for core app
├── Dockerfile.songs         # Fly.io Dockerfile for songs app
├── fly.core.toml            # Fly.io config for core app
├── fly.songs.toml           # Fly.io config for songs app
├── .dockerignore             # Docker build exclusions (monorepo root context)
├── bin/fly-deploy            # Deploy convenience script
├── core/
│   ├── litefs.yml            # LiteFS config (copied to /etc/litefs.yml in Docker)
│   ├── bin/fly-entrypoint    # Startup script (node role detection, Puma)
│   ├── Dockerfile            # Kamal Dockerfile (unchanged)
│   └── ...
├── songs/
│   ├── litefs.yml
│   ├── bin/fly-entrypoint
│   ├── Dockerfile            # Kamal Dockerfile (unchanged)
│   └── ...
└── shared/djm_jwt/           # Shared JWT gem (copied into Docker image)
```
