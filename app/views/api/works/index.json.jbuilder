json.works @works do |work|
  json.id    work.id
  json.title work.title
  json.pseud work.pseud

  json.artist_id album.artist ? album.artist.id : nil
end