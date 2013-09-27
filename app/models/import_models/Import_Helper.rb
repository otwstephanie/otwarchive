class ImportHelper
#get all possible tags from source
# @param [array]  tl
  def get_tag_list(tl)
    tag_list = tl
    case @source_archive_type
      when 4 ## storyline
             ## Categories
        tag_list = get_tag_list_helper("Select caid, caname from #{@source_categories_table}; ", "Category", tag_list)
        tag_list = get_tag_list_helper("Select subid, subname from #{@source_subcategories_table}; ", 99, tag_list)
      when 3 ## efiction 3
             ## classes
        tag_list = get_tag_list_helper("Select class_id, class_type, class_name from #{@source_classes_table}; ", "Freeform", tag_list)
        ## categories
        tag_list = get_tag_list_helper("Select catid, category from #{@source_categories_table}; ", "Freeform", tag_list)
        ## characters
        tag_list = get_tag_list_helper("Select charid, charname from #{@source_characters_table}; ", "Character", tag_list)

      when 2 ## efiction 2
             ## categories
        tag_list = get_tag_list_helper("Select catid, category from #{@source_categories_table}; ", "Freeform", tag_list)
        ## characters
        tag_list = get_tag_list_helper("Select charid, charname from #{@source_characters_table}; ", "Character", tag_list)
      else
        puts "Error: (get_tag_list): Invalid or source archive type, or type not currently implemented"
    end
    return tag_list
  end


  #assign row data to import_Work object
  # @param [import_work] ns
  # @param [mysql_row] row
  def assign_row_import_work(ns, row)
    ns.source_archive_id = @archive_import_id

    case @source_archive_type
      when 4 ## storyline
        ns.old_work_id = row[0]
        #puts ns.old_work_id
        ns.title = row[1]
        #debug info
        #puts ns.title
        ns.summary = row[2]
        ns.old_user_id = row[3]
        ns.rating_integer = row[4]
        #Assign Tags
        rating_tag = ImportTag.new()
        rating_tag.tag_type = "Freeform"
        rating_tag.new_id = ns.rating_integer
        ns.tag_list.push(rating_tag)
        ns.published = row[5]
        cattag = ImportTag.new()
        subcattag = ImportTag.new()
        if @use_proper_categories == 1
          cattag.tag_type = Category
          subcattag.tag_type = "Category"
        else
          subcattag.tag_type = "Freeform"
          cattag.tag_type = "Freeform"
        end
        cattag.new_id = row[6]
        subcattag.new_id =row[11]
        ns.tag_list.push(cattag)
        ns.tag_list.push(subcattag)
        ns.updated = row[9]
        ns.completed = row[12]
        ns.hits = row[10]

      when 3 ## efiction 3
        ns.old_work_id = row[0]
        ns.title = row[1]
        ns.summary = row[2]
        ns.old_user_id = row[10]
        ns.classes = row[5]
        ns.categories = row[4]
        ns.characters = row[6]
        ns.rating_integer = row[7]
        rating_tag = ImportTag.new()
        rating_tag.tag_type = "Freeform"
        rating_tag.new_id = ns.rating_integer
        ns.tag_list.push(rating_tag)
        ns.published = row[8]
        ns.updated = row[9]
        ns.completed = row[14]
        ns.hits = row[18]
        if !@source_warning_class_id == nil
          #todo why did you have this here? steph 9-9-13
        end
        ## fill taglist with import tags to be added
        ns.tag_list = get_source_work_tags(ns.tag_list, ns.classes, "classes")
        puts "Getting class tags: tag count = #{ns.tag_list.count}"
        ns.tag_list = get_source_work_tags(ns.tag_list, ns.characters, "characters")
        if @categories_as_tags == 1
          ns.tag_list = get_source_work_tags(ns.tag_list, ns.categories, "categories")
          puts "Getting category tags: tag count = #{ns.tag_list.count}"
        end
      else
        puts "Error: (assign_row_import_work): Invalid source archive type, or type not yet Implemented."
    end
    return ns
  end

  ##get import user object, by source_user_id,
  ##return import user object
  # @param [integer]  source_user_id
  # @return [ImportUser]  ImportUser Object
  def get_import_user_object_from_source(source_user_id)
    a = ImportUser.new()
    r = @connection.query("#{@source_author_query} #{source_user_id}")
    @connection

    r.each do |row|
      a.old_user_id = source_user_id
      a.realname = row[0]
      a.source_archive_id = @archive_import_id
      a.penname = row[1]
      a.email = row[2]
      a.bio = row[3]
      a.joindate = row[4]
      a.password = row[5]
      if @source_archive_type == 2 || @source_archive_type == 4
        a.website = row[6]
        a.aol = row[7]
        a.msn = row[8]
        a.icq = row[9]
        a.bio = self.build_bio(a).bio
        a.yahoo = ""
        if @source_archive_type == 2
          a.yahoo = row[10]
          a.is_adult = row[11]
        end
      end
    end
    return a
  end

  ####
  #used with efiction 3 archives to get values to be gotten as tags
  # @param [array] tl import tag array
  # @param [string] class_str
  # @param [string]  my_type tag type
  def get_source_work_tags(tl, class_str, my_type)
    query = ""
    new_tag_type = ""
    class_string = String.new(str=class_str)
    class_split = Array.new
    class_split = class_string.split(",")
    class_split.each do |x|
      case my_type
        when "characters"
          new_tag_type = "Character"
          query = "Select charid, charname from #{@source_characters_table} where charid = #{x}"
        when "classes"
          query = "Select class_id,  class_name, class_type from #{@source_classes_table} where class_id = #{x}"
          new_tag_type = "Freeform"
        when "categories"
          new_tag_type = "Freeform"
          query = "Select catid, category, parentcatid from #{@source_categories_table} where catid = #{x}"
        # Todo: add @use_warning_tags as an option (for future use, non ao3) ,Steph
        # when "warning"
        #   new_tag_type = "Warning"

        else
          puts "Error: (get_source_work_tags): Invalid tag  type"
      end
      r = @connection.query(query)
      r.each do |row|
        nt = ImportTag.new()
        nt.tag_type= new_tag_type
        nt.old_id = row[0]
        nt.tag = row[1]
        tl.push(nt)
      end
    end
    return tl
  end
=begin
  #create child collection, set archivist as owner, takes name, parentid, descrip,title
  # todo add bool to archive settings for allow child collections and restrict based on value
  # @param [string] name
  # @param [integer] parent_id
  # @param [string] description
  # @param [string] title
  def create_child_collection(name, parent_id, description, title)
    collection = Collection.new(
        name: name,
        description: description,
        title: title,
        parent_id: parent_id
    )
    user = User.find(@archivist_user_id)
    collection.collection_participants.build(
        pseud: user.default_pseud,
        participant_role: "Owner"
    )
    collection.save
    return collection.id
  end
=end

=begin
  #Convert Categories To Collections
  #@param [integer] level
  def convert_categories_to_collections(level)
    case level
      when 0
        case @source_archive_type
          when 3
            rr = @connection.query("Select catid,parentcatid,category,description from #{@source_categories_table} where parentcatid = -1")
            rr.each do |r3|
              ic = ImportCategory.new
              ic.category_name=r3[2].gsub(/\s+/, "")
              ic.new_id= 0
              ic.old_id=r3[0]
              ic.new_parent_id=@new_collection_id
              ic.old_parent_id=r3[1]
              ic.title=r3[2]
              ic.description=r3[3]
              if ic.description == nil then
                ic.description = ""
              end
              puts "old parent #{ic.old_parent_id}"
              puts "new parent #{ic.new_parent_id}"
              ic.new_id= create_child_collection(ic.category_name, ic.new_parent_id, ic.description, ic.title)
              nci = CollectionImport.new
              nci.old_id = ic.old_id
              nci.new_id = ic.new_id
              nci.source_archive_id = @archive_import_id
              nci.save!
            end
            convert_categories_to_collections(1)
          when 4
          else

        end
      else
        case @source_archive_type
          when 3
            rr = @connection.query("Select catid,parentcatid,category,description from #{@source_categories_table} where parentcatid > 0")
            rr.each do |r3|
              ic = ImportCategory.new
              ic.category_name=r3[2].gsub(/\s+/, "")
              ic.new_id= 0
              ic.old_id=r3[0]
              ic.old_parent_id=r3[1]
              ic.title=r3[2]
              ic.description=r3[3]
              if ic.description == nil then
                ic.description = ""
              end
              puts "old parent #{ic.old_parent_id}"
              ic.new_parent_id = get_single_value_target("Select new_id from collection_imports where old_id = #{ic.old_parent_id} and source_archive_id = #{@archive_import_id}")
              puts "new parent #{ic.new_parent_id}"
              ic.new_id= create_child_collection(ic.category_name, ic.new_parent_id, ic.description, ic.title)
              nci = CollectionImport.new
              nci.old_id = ic.old_id
              nci.new_id = ic.new_id
              nci.source_archive_id = @archive_import_id
              nci.save!
            end
          when 4
            #reserved
          else
            #reserved

        end

    end
  end
=end

#helper function for get tag list, takes query, tagtype as string, taglist array of import tag
# @param [string] query
# @param [string] tag_type
# @param [array] tl
  def get_tag_list_helper(query, tag_type, tl)
    ## categories
    r = @connection.query(query)
    count_value = get_row_count(r)
    puts "row count!!!!!!!!!!!!!! #{count_value}"
    r.each do |row|
      nt = ImportTag.new()
      nt.tag_type = tag_type
      nt.old_id = row[0]
      nt.tag = row[1]
      tl.push(nt)
      puts "tag testing" + nt.tag
    end
    return tl
  end
end