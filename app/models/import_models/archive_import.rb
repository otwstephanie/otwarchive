# ArchiveImport AR Model
class ArchiveImport < ActiveRecord::Base
  attr_accessible :old_url_link
  attr_accessible :archivist_link
  attr_accessible :new_url_link
  attr_accessible :notes
  attr_accessible :associated_collection_id
  attr_accessible :name,
  attr_accessible :old_base_url
  attr_accessible :new_url

  def build_links()
    @old_url_link = "<a href=\"http://#{self.old_base_url}>#{self.name}</a>"
    @old_url_link = "<a href=\"http://#{self.new_url}>#{self.name} - at Ao3</a>"
    u = User.find(self.archivist_id)
    @archivist_link = "<a href=\"mailto://#{u.email}>#{u.login}</a>"
  end
end