defmodule JusticeDialer.LoginMailer do
  use Phoenix.Swoosh,
    view: JusticeDialer.EmailView,
    layout: {JusticeDialer.EmailView, :email}

  require Logger

  def on_vox_login_claimed(%{
        "username" => username,
        "date" => date,
        "name" => name,
        "email" => email,
        "phone" => phone,
        "source" => source,
        "action_calling_from" => action_calling_from
      }) do
    Logger.info("Sending email to Sam because someone claimed: #{username}")

    new()
    |> to({"Sam Briggs", "sam@justicedemocrats.com"})
    |> to({"Ben Packer", "ben@justicedemocrats.com"})
    |> from({"Robot", "robot@justicedemocrats.com"})
    |> subject("New Vox Login Claimed!")
    |> render_body("event-failure.text", %{raw: "
Username: #{username}
Date: #{date}
Name: #{name}
Email: #{email}
Phone: #{phone}
Source: #{source}
From: #{action_calling_from}
"})
    |> JusticeDialer.Mailer.deliver()
    |> IO.inspect()
  end
end
