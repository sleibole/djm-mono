class ApplicationMailer < ActionMailer::Base
  default from: "DJMagic <noreply@djmagic.io>",
          "X-SES-CONFIGURATION-SET" => "djmagic-app"

  layout "mailer"
end
