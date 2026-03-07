class AuthMailer < ApplicationMailer
  def magic_link(user, raw_token)
    @user = user
    @magic_link_url = auth_magic_link_url(token: raw_token)
    @new_user = !user.email_confirmed?

    mail(to: user.email, subject: "Your DJMagic.io login link")
  end
end
