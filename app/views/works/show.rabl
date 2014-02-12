object @work

# Declare the properties to include
attributes :title, :summary, :word_count, :id, :updated_at, :created_at




# Include a custom node with app url
node :work_url do |work|
  ArchiveConfig.APP_URL + "/works/" + work.id
end

