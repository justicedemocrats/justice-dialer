defmodule Db do
  import ShortMaps

  def find_login(query) do
    Mongo.find_one(:mongo, "dialer_logins", query)
  end

  def reset_claimed(client) do
    Mongo.update_one(
      :mongo,
      "dialer_login_metadata",
      %{"client" => client},
      %{"$set" => %{"claimed_count" => 0}},
      upsert: true
    )
  end

  def inc_claimed(client) do
    IO.puts "Incing claimed for #{client}"

    Mongo.update_one(:mongo, "dialer_login_metadata", %{"client" => client}, %{
      "$inc" => %{"claimed_count" => 1}
    })
    |> IO.inspect()

    ~m(claimed_count) = IO.inspect Mongo.find_one(:mongo, "dialer_login_metadata", %{"client" => client})
    claimed_count
  end

  def insert_logins(docs) do
    Mongo.insert_many(:mongo, "dialer_logins", docs)
  end

  def delete_logins do
    Mongo.delete_many(:mongo, "dialer_logins", %{})
  end

  def logins_for_client(client) do
    Mongo.find(:mongo, "dialer_logins", %{"client" => client})
  end
end
