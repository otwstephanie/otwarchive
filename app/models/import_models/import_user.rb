#Internal ImportUser Object
class ImportUser
extend ActiveModel::Naming
include ActiveModel::Conversion
include ActiveModel::Validations
extend ActiveModel::Translation

attr_accessor :old_username
attr_accessor :realname
attr_accessor :penname
attr_accessor :password_salt
attr_accessor :password
attr_accessor :old_user_id
attr_accessor :joindate
attr_accessor :bio
attr_accessor :aol
attr_accessor :source_archive_id
attr_accessor :website
attr_accessor :yahoo
attr_accessor :msn
attr_accessor :icq
attr_accessor :new_user_id
attr_accessor :email
attr_accessor :is_adult
attr_accessor :pseud_id

# Consolidate Author Fields into User About Me String
  def build_bio()
    if self.yahoo == nil
      self.yahoo = " "
    end
    if self.aol.length > 1 || self.yahoo.length > 1 || self.website.length > 1 || self.icq.length > 1 || self.msn.length > 1
      if self.bio.length > 0
        self.bio << "<br /><br />"
      end
    end
    if self.aol.length > 1
      self.bio << " <br /><b>AOL / AIM :</b><br /> #{self.aol}"
    end
    if self.website.length > 1
      self.bio << "<br /><b>Website:</ b><br /> #{self.website}"
    end
    if self.yahoo.length > 1
      self.bio << "<br /><b>Yahoo :</b><br /> #{self.yahoo}"
    end
    if self.msn.length > 1
      self.bio << "<br /><b>Windows Live:</ b><br /> #{self.msn}"
    end
    if self.icq.length > 1
      self.bio << "<br /><b>ICQ :</b><br /> #{self.icq}"
    end
  end


end