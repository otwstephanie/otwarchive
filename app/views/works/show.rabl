object @work

# Declare the properties to include
attributes :title, :summary

child :chapters, :object_root => false do
  attributes :title, :position, :content
end
child :tags, :object_root => false do
    attributes :name, :type
end