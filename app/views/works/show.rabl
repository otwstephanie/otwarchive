object @work

# Declare the properties to include
attributes :title, :summary


child :chapters do
  attributes :title, :position, :content
end