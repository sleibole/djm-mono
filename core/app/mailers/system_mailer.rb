class SystemMailer < ApplicationMailer
  def ses_test_email(to:)
    mail(to: to, subject: "DJMagic SES test email")
  end
end
