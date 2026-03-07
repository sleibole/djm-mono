# Preview all emails at http://localhost:3000/rails/mailers/auth_mailer
class AuthMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/auth_mailer/magic_link
  def magic_link
    AuthMailer.magic_link
  end
end
