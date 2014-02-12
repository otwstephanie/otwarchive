object @work


attributes :title, :summary, :updated_at
attribute :created_at => :posted_at

child :pseuds do
  attribute :name => :creator
end

child :chapters, :object_root => false do
  attributes :title, :position, :content
end
child :tags, :object_root => false do
    attributes :name, :type
end