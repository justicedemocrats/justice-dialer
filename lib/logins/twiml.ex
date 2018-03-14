defmodule JusticeDialer.Twiml do
  import ExTwiml

  def say_message(message) do
    twiml do
      say(message, voice: "woman")
    end
  end
end
