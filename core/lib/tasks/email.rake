namespace :email do
  desc "Send a test email via SES: rake email:test[to@example.com]"
  task :test, [ :to ] => :environment do |_t, args|
    abort "Usage: rake email:test[to@example.com]" if args[:to].blank?

    SystemMailer.ses_test_email(to: args[:to]).deliver_now
    puts "Test email sent to #{args[:to]}"
  end
end
