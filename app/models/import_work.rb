class ImportWork
  include SAXMachine
  elements :author, :as => :authors
  elements :author, :as => :tags
  element :title
  element :summary


end