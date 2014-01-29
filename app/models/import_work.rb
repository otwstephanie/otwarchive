class ImportWork
  include SAXMachine
  elements :AUTHOR, :as => :authors
  elements :TAG, :as => :tags
  element :TITLE
  element :SUMMARY


end