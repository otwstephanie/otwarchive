json.collection do
  json.id    @collection.id
  json.title @album.title

  json.artist_id @album.artist ? @album.artist.id : nil
end