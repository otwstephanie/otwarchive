class Import
  require "bunny"

  @response = nil
  def exchange(payload)
    response = nil
    conn = Bunny.new
    conn.start
    ch   = conn.create_channel
    client   = ImportHelper.new(ch, "import_queue")
    response = client.call(payload)
    ch.close
    conn.close
    return response
  end
end