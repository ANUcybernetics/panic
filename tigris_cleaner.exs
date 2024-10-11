# NOTE: only use this if you know what you're doing
Mix.install([
  {:req, "~> 0.5"},
  {:req_s3, "~> 0.2"}
])

defmodule TigrisCleaner do
  @moduledoc false
  def delete_all(bucket) do
    req = ReqS3.attach(Req.new())

    # List all objects in the bucket
    %{body: body} = Req.get!(req, url: "s3://#{bucket}")

    # Extract the keys of all objects
    keys = get_in(body, ["ListBucketResult", "Contents", Access.all(), "Key"])

    # Delete each object
    Enum.each(keys, fn key ->
      Req.delete!(req, url: "s3://#{bucket}/#{key}")
    end)
  end
end

# Usage
TigrisCleaner.delete_all("panic-invocation-outputs")
