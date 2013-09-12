# encoding=utf-8
# Mass Import Tool
# Questions? Ask Stephanie =)
class MassImportTool
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::TagHelper #tag_options needed by auto_link
  require 'mysql'

  def initialize
    #Import Class Version Number
    @version = 1
    #################################################
    #Database Settings
    ###############################################
    @sql_filename = "rescued_archive.sql"
    @database_host = "localhost"
    @database_username = "stephanies"
    @database_password = "Trustno1"
    @database_name = "stephanies_development"
    @temp_table_prefix = "testing"
    @apply_temp_prefix = 1

    #NOTE! change to nil for final version, as there will be no default
    @connection = Mysql.new(@database_host, @database_username, @database_password, @database_name)
    #####################################################

    #Archivist Settings
    ###################
    @create_archivist_account = true
    @archivist_login = "StephanieTest"
    @archivist_password = "password"
    @archivist_email = "stephaniesmithstl@gmail.com"
    @archivist_user_id = 0
    @archive_has_chapter_files = 1
    @archive_chapters_filename = "chapters.zip"
    #Import Settings
    ####################

    #Import Job Name
    @import_name = "New Import"
    @import_fandom = "Harry Potter"

    #Create record for imported archive (false if already exists)
    @create_archive_import_record = true

    #will error if not unique, just let it automatically create it and assign it if you are unsure
    #Import Archive ID
    @archive_import_id = 106

    #Import Reviews (true / false)
    @import_reviews = false

    #Match Existing Authors by Email-Address
    @match_existing_authors = true

    #category mapping
    #================
    @categories_as_sub_collections = false
    #Categories as sub-collections isn't supported at Ao3, left for later use by other archives
    @categories_as_tags = true
    @subcategory_depth = 1
    #values "merge_top" "move_top" "drop" "merge all" "custom"
    @subcategory_remap_method = "merge_top"
    #TODO implement modified subcat code
    #NOTE: THE ABOVE CAN WAIT AS subcats are not in the ao3 workings, will be available for future use
    #Message Values
    ####################################
    ##If true, send invites unconditionally,
    # if false add them to the que to be sent when it gets to it, could be delayed.
    @bypass_invite_que = true

    #Send notification email with invitation to archive to imported users
    @notify_imported_users = true

    #Send message for each work imported? (or 1 message for all works)
    @send_individual_messages = false

    @new_user_email_id = 0
    @existing_user_email_id = 0

    @new_user_notice_id = 0
    @existing_user_notice_id = 0

    #New Collection Values
    #####################################
    #ID Of the newly created collection, filled with value automatically if create collection is true

    @create_collection = true
    @new_collection_id = 123456789
    @new_collection_owner = "StephanieTest"
    @new_collection_owner_pseud = "1010"
    @new_collection_title = "The Quidditch Pitch Test"
    @new_collection_name = "tqptest"
    @new_collection_description = "The Quidditch Pitch Test"

    #=========================================================
    #Destination Options / Settings
    #=========================================================
    @new_url = ""
    @check_archivist_activated = true
    #If using ao3 cats, sort or skip
    @SortForAo3Categories = true

    #Import categories as categories or use ao3 cats
    @use_proper_categories = false

    #Destination otwarchive Ratings (1 being NR if NR Is conservative, 5 if not)
    @target_rating_1 = 9 #not rated
    @target_rating_2 = 10 #general
    @target_rating_3 = 11 #Teen
    @target_rating_4 = 12 #Mature
    @target_rating_5 = 13 #Explicit

    #========================
    #Source Variables
    #========================
    "Old Archive URL"
    @source_base_url = "http://thequidditchpitch.org"
    #Source Archive Type
    @source_archive_type = 3

    #If archivetype being imported is efiction 3 >  then specify what class holds warning information
    @source_warning_class_id = 1

    #Holds Value for source table prefix
    @source_table_prefix = "fanfiction_"

    ################# Self Defined based on above
    @source_ratings_table = nil #Source Ratings Table
    @source_users_table = nil #Source Users Table
    @source_stories_table = nil #Source Stories Table
    @source_reviews_table = nil #Source Reviews Table
    @source_chapters_table = nil #Source Chapters Table
    @source_characters_table = nil #Source Characters Table
    @source_subcatagories_table = nil #Source Subcategories Table
    @source_categories_table = nil #Source Categories Table
    @source_author_query = nil #source author query
    @source_series_table = nil #Source Series Table
    @source_inseries_table = nil #Source inseries Table
    #############
    #debug stuff
    @debug_update_source_tags = true
    #Skip Rating Transformation (ie if import in progress or testing)
    @skip_rating_transform = false
  end

  #helper function for get tag list, takes query, tagtype as string, taglist array of import tag
  # @param [string] query
  # @param [string] tag_type
  # @param [array] tl
  def get_tag_list_helper(query, tag_type, tl)
    ## categories
    r = @connection.query(query)
    r.each do |row|
      nt = ImportTag.new()
      nt.tag_type = tag_type
      nt.old_id = row[0]
      nt.tag = row[1]
      tl.push(nt)
    end
    return tl
  end

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

  #ensure all source tags exist in target in some form
  #uses array of ImportTag created from get_tag_list
  def fill_tag_list(tl)
    i = 0
    while i <= tl.length - 1
      temp_tag = tl[i]
      escaped_tag_name = @connection.escape_string(temp_tag.tag)
      r = @connection.query("Select id from tags where name = '#{escaped_tag_name}'; ")
      ## if not found add tag
      if !temp_tag.tag_type == "Category" || 99
        if r.num_rows == 0
          # '' self.update_record_target("Insert into tags (name, type) values ('#{temptag.tag}','#{temptag.tag_type}');")
          temp_new_tag = Tag.new()
          temp_new_tag.type = "#{temp_tag.tag_type}"
          temp_new_tag.name = "#{temp_tag.tag}"
          temp_new_tag.save
          temp_tag.new_id = temp_new_tag.id
        else
          r.each do |row_a|
            temp_tag.new_id = row_a[0]
          end
        end
      else
        if @categories_as_tags
          if r.num_rows == 0
            # '' self.update_record_target("Insert into tags (name, type) values ('#{temptag.tag}','#{temptag.tag_type}');")
            temp_new_tag = Tag.new()
            temp_new_tag.type = "Freeform"
            temp_new_tag.name = "#{temp_tag.tag}"
            temp_new_tag.save
            temp_tag.new_id = temp_new_tag.id
          else
            r.each do |row|
              temp_tag.new_id = row[0]
            end
          end
        end
      end
      ## return importtag object with new id and its corresponding data ie old id and tag to array
      tl[i] = temp_tag
      i = i + 1
    end
    return tl
  end


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

  #Create new chapter comment
  # @param [String] content
  # @param [Date] date
  # @param [integer] chap_id
  # @param [string] email
  # @param [string] name
  # @param [integer] pseud
  def create_chapter_comment(content, date, chap_id, email, name, pseud)
    new_comment = Comment.new
    new_comment.commentable_type="Chapter"
    new_comment.content=content
    new_comment.created_at=date
    new_comment.commentable_id=chap_id
    #todo lookup existing users and map
    new_comment.email=email
    new_comment.name=name
    new_comment.save
  end

  #import chapter reviews for efic 3 story takes old chapter id, new chapter id
  # @param [integer] old_chapter_id
  # @param [integer] new_chapter_id
  def import_chapter_reviews(old_chapter_id, new_chapter_id)
    r = @connection.query("Select reviewer, uid,review,date,rating from #{@source_reviews_table} where chapid=#{old_chapter_id}")
    #only run if we have reviews
    if r.num_rows >=1
      r.each do |row|
        email = get_single_value_target("Select email from #{@source_users_table} where uid = #{row[1]}")
        create_chapter_comment(row[2], row[3], new_chapter_id, email, row[0], 0)
      end
    end

  end

  #assign row data to import_Work object
  # @param [import_work] ns
  # @param [mysql_row] row
  def assign_row_import_work(ns, row)
    case @source_archive_type
      when 4   ## storyline
        ns.source_archive_id = @archive_import_id
        ns.old_work_id = row[0]
        #puts ns.old_work_id
        ns.title = row[1]
        #debug info
        #puts ns.title
        ns.summary = row[2]
        ns.old_user_id = row[3]
        ns.rating_integer = row[4]
        rating_tag = ImportTag.new()
        rating_tag.tag_type = "Freeform"
        rating_tag.new_id = ns.rating_integer
        ns.tag_list.push(rating_tag)
        ns.published = row[5]
        cattag = ImportTag.new()
        subcattag = ImportTag.new()
        if @use_proper_categories
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

      when 3    ## efiction 3
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
        if @categories_as_tags
          ns.tag_list = get_source_work_tags(ns.tag_list, ns.categories, "categories")
          puts "Getting category tags: tag count = #{ns.tag_list.count}"
        end
      else
        puts "Error: (assign_row_import_work): Invalid source archive type"
    end
    return ns
  end

  #create import record
  # @return [integer]  import archive id
  def create_import_record
    # todo update to use ar new method and save since is proper ar class now, make sure it returns new value after save - steph 9-9-13
    update_record_target("insert into archive_imports (name,archive_type_id,old_base_url,associated_collection_id,new_user_notice_id,existing_user_notice_id,existing_user_email_id,new_user_email_id,new_url,archivist_user_id)  values ('#{@import_name}',#{@source_archive_type},'#{
    @source_base_url}',#{@new_collection_id},#{@new_user_notice_id},#{@existing_user_notice_id},#{@new_user_email_id},#{@existing_user_email_id},'#{@new_url}',#{@archivist_user_id})")
    archive_import = ArchiveImport.find_by_old_base_url(@source_base_url)
    return archive_import.id
  end

  #create new pseud
  # @param [integer] user_id
  # @param [string] penname
  # @param [true/false] default
  # @param [string] description
  # @return [integer]  new pseud id
  def create_new_pseud(user_id, penname, default, description)
    begin
      new_pseud = Pseud.new
      new_pseud.user_id = user_id
      new_pseud.name = penname
      new_pseud.is_default = default
      new_pseud.description = description
      new_pseud.save!
      return new_pseud.id
    rescue Exception => e
      puts "Error: 111: #{e}"
      return 0
    end
  end

  ##################################################################################################
  # Main Worker Sub
  def import_data
    puts "1) Setting Import Values"
    self.set_import_strings(@source_archive_type)
    ## create collection & archivist
    self.create_archivist_and_collection
    ## create import record
    self.create_import_record
    ## set file upload path with import id from previous step
    @import_files_path = "#{Rails.root.to_s}/imports/#{@archive_import_id}"
    ## check that import directory exists if not create it , do other import processes move extract etc
    puts "2) Running File Operations"
    run_file_operations
    ## Update Tags and get Taglist
    puts "3) Updating Tags"
    tag_list = Array.new()
    ## create list of all tags used in source
    tag_list = get_tag_list(tag_list)
    ## check for tag existance on target archive
    tag_list = self.fill_tag_list(tag_list)

    ## pull source stories
    r = @connection.query("SELECT * FROM #{@source_stories_table} ;")
    puts "4) Importing Stories"
    i = 0
    r.each do |row|
      puts " Importing Story #{i}"
      ## create new ImportWork Object
      ns = ImportWork.new()
      ## create new importuser object
      #a = ImportUser.new()
      ## Create Taglisit for this story
      my_tag_list = Array.new()
      ns.tag_list = my_tag_list

      ## assign data to import work object
      ns = assign_row_import_work(ns, row)
      my_tag_list = ns.tag_list
      ## Set source archive id for new story / work object
      ns.source_archive_id = @archive_import_id
      puts "attempting to get new user id, user: #{ns.old_user_id}, source: #{ns.source_archive_id}"
      ## goto next if no chapters
      num_source_chapters = 0
      num_source_chapters = get_single_value_target("Select chapid  from #{@source_chapters_table} where sid = #{ns.old_work_id} limit 1")
      next if num_source_chapters == 0
      #todo log oldsid / story name to error log with unimportable error , reason no source chapters

      ## see if user / author exists for this import already
      ns.new_user_id = self.get_new_user_id_from_imported(ns.old_user_id, @archive_import_id)
      puts "The New user id!!!! ie value at this point #{ns.new_user_id}"

      ## get import user object from source database
      a = self.get_import_user_object_from_source(ns.old_user_id)
      if ns.new_user_id == 0
        puts "user didnt exist in this import session"
        ## see if user account exists in main archive by checking email,
        temp_author_id = get_user_id_from_email(a.email)
        if temp_author_id == 0
          ## if not exist , add new user with user object, passing old author object
          #new_a = ImportUser.new
          new_a = self.add_user(a)
          ## pass values to new story object
          ns.penname = new_a.penname
          ns.new_user_id = new_a.new_user_id
          ## debug info
          puts "newid = #{new_a.new_user_id}"
          ## get newly created pseud id
          new_pseud_id = get_default_pseud_id(ns.new_user_id)
          ## set the penname on newly created pseud to proper value
          update_record_target("update pseuds set name = '#{ns.penname}' where id = #{new_pseud_id}")
          ## create user import
          create_user_import(new_a.new_user_id, new_pseud_id, ns.old_user_id)
          ns.new_pseud_id = new_pseud_id
        else
          ## user exists, but is being imported
          ## insert the mapping value
          puts "Debug: User existed in Target Archive"
          ns.penname = a.penname
          ## check to see if penname exists as pseud for existing user
          temp_pseud_id = get_pseud_id_for_penname(temp_author_id, ns.penname)
          if temp_pseud_id == 0
            ## add pseud if not exist
            temp_pseud_id = create_new_pseud(temp_author_id, a.penname, true, "Imported")
            ns.new_pseud_id = temp_pseud_id
            ## create USER IMPORT
            create_user_import(temp_author_id, temp_pseud_id, ns.old_user_id)
            # 'temp_pseud_id = get_pseud_id_for_penname(ns.new_user_id,ns.penname)
            update_record_target("update user_imports set pseud_id = #{temp_pseud_id} where user_id = #{ns.new_user_id} and source_archive_id = #{@archive_import_id}")
            ns.new_user_id = temp_pseud_id
            a.pseud_id = temp_pseud_id
          end
        end
      else
        ns.penname = a.penname
        a.pseud_id = get_pseud_id_for_penname(ns.new_user_id, ns.penname)
        puts "#{a.pseud_id} this is the matching pseud id"
        ns.new_pseud_id = a.pseud_id
      end
      ## insert work object
      puts "Making new work!!!!"
      new_work = prepare_work(ns)
      next if new_work.chapters[0].content.length < 5
      new_work.save!
      add_chapters(new_work, import_work.old_work_id, false)
      ## attempt to add id to first chapter
      puts "post save chapter count = #{new_work.chapters.size}"

      puts new_work.errors
      puts "New Work ID = #{new_work.id}"

      ## add all chapters to work
      new_work.expected_number_of_chapters = new_work.chapters.count
      new_work.save

      puts "taglist count = #{my_tag_list.count}"
      my_tag_list.each do |t|
        add_work_taggings(new_work.id, t)
      end

      ## save first chapter reviews since cand do it in addchapters like rest
      old_first_chapter_id = get_single_value_target("Select chapid from  #{@source_chapters_table} where sid = #{ns.old_work_id} order by inorder asc Limit 1")
      import_chapter_reviews(old_first_chapter_id, new_work.chapters.first.id)

      ## create new work import
      create_new_work_import(new_work, ns)
      format_chapters(new_work.id)
      i = i + 1
    end
    ## import series
    import_series
    @connection.close()

  end

  #create user import
  # @param [integer] author_id
  # @param [integer] pseud_id
  # @param [integer] old_user_id
  def create_user_import(author_id, pseud_id, old_user_id)
    begin
      new_ui = UserImport.new
      new_ui.user_id = author_id
      new_ui.pseud_id = pseud_id
      new_ui.source_user_id = old_user_id
      new_ui.source_archive_id = @archive_import_id
      new_ui.save!
      return new_ui.id
    rescue Exception => e
      puts "Error: 777: function create_user_import #{e}"
      return 0
    end
  end

  #Create new work import, takes Work , ImportWork
  # @param [work] new_work
  # @param [importwork] ns
  def create_new_work_import(new_work, ns)
    begin
      new_wi = WorkImport.new
      new_wi.work_id = new_work.id
      new_wi.pseud_id = ns.new_user_id
      new_wi.source_archive_id = @archive_import_id
      new_wi.source_work_id = ns.old_work_id
      new_wi.source_user_id = ns.old_user_id
      new_wi.save!
      return new_wi.id
    rescue Exception => e
      puts "Error in function create_new_work import: #{e}"
      return 0
    end
  end

  #save chapters, takes Work
  # @param [Work]  new_work
  def save_chapters(new_work)
    puts "number of chapters: #{new_work.chapters.count} "
    begin
      new_work.chapters.each do |cc|
        puts "attempting to save chapter for #{new_work.id}"
        cc.work_id = new_work.id
        cc.save
        cc.errors.full_messages
      end
      puts "chapter saved"
    rescue Exception => ex
      puts error "3318: saving chapter - error in function save_chapters #{ex}"
    end
  end

  # Create New Series Work
  # @param [integer] series_id
  # @param [integer] position
  # @param [integer] work_id
  def create_series_work(series_id, position, work_id)
    sw = SerialWork.new
    sw.position=position
    sw.work_id=work_id
    sw.series_id=series_id
    sw.save
    return sw.id
  end

  #import series objects
  def import_series
    #create the series objects in new archive
    r = @connection.query("Select seriesid,title,summary,uid,rating,classes,characters, isopen from #{@source_series_table}")
    if r.num_rows >= 1
      r.each do |row|
        #s = Series.new
        s = create_series(row[1], row[2], row[7])
        import_series_works(row[0], s.id)
      end
    end
  end

  #import works into new series
  # @param [integer] old_series_id
  # @param [integer] new_series_id
  def import_series_works(old_series_id, new_series_id)
    r = @connection.query("SELECT #{@source_inseries_table}.inorder, #{@source_inseries_table}.seriesid, work_imports.work_id
    FROM work_imports INNER JOIN #{@source_inseries_table} ON #{@source_inseries_table}.sid = work_imports.source_work_id
    WHERE #{@source_inseries_table}.seriesid = #{old_series_id} order by inorder asc")
    r.each do |row|
      work = Work.find(row[2])
      work.series_attributes = {id: new_series_id}
      work.save
    end
  end

  #create series
  # @param [string] title
  # @param [string] summary
  # @param [boolean] completed
  # @return [integer] new series id
  def create_series(title, summary, completed)
    begin
      s = Series.new
      s.complete=completed
      s.summary=summary
      s.title = title
      s.save!
      return s.id
    rescue
      return 0
    end
  end

  #Create work and return once saved, takes ImportWork
  # @return [Work] returns newly created work object
  # @param [ImportWork]  import_work
  def prepare_work(import_work)
    new_work = Work.new
    new_work.title = import_work.title
    puts "Title to be = #{new_work.title}"
    new_work.summary = import_work.summary
    puts "summary to be = #{new_work.summary}"
    new_work.authors_to_sort_on = import_work.penname
    new_work.title_to_sort_on = import_work.title
    new_work.restricted = true
    new_work.posted = true
    puts "looking for pseud #{import_work.new_pseud_id}"
    #new_work.pseuds << Pseud.find_by_id(import_work.new_pseud_id)
    new_work.authors = [Pseud.find_by_id(import_work.new_pseud_id)]
    new_work.revised_at = Date.today
    new_work.created_at = Date.today

    new_work.revised_at = import_work.updated
    new_work.created_at = import_work.published
    puts "revised = #{new_work.revised_at}"
    puts "crated at  = #{new_work.created_at}"
    new_work.fandom_string = @import_fandom
    new_work.rating_string = "Not Rated"
    new_work.warning_strings = "None"
    puts "old work id = #{import_work.old_work_id}"
    new_work.imported_from_url = "#{@archive_import_id}~~#{import_work.old_work_id}"
    new_work = add_chapters(new_work, import_work.old_work_id, true)
    #debug info
=begin
    new_work.chapters.each do |chap|
      puts "#{chap.title}"
      puts "#{chap.content}"
    end
=end
    puts "chapters in new_work.chapters = #{new_work.chapters.size}"
    ##assign to main import collection
    new_work.collections << Collection.find(@new_collection_id)
    if @categories_as_sub_collections
      collection_array = get_work_collections(import_work.categories)
      collection_array.each do |cobj|
        new_work.collections << cobj unless new_work.collections.include?(cobj)
      end
    end


    return new_work
  end


  #copied and modified from mass import rake, stephanies 1/22/2012
  #Create archivist and collection if they don't already exist"
  def create_archivist_and_collection

    # make the archivist user if it doesn't exist already
    u = User.find_or_initialize_by_login(@archivist_login)
    if u.new_record?
      u.password = @archivist_password
      u.email = @archivist_email
      u.age_over_13 = "1"
      u.terms_of_service = "1"
      #below line might not be needed
      u.password_confirmation = @archivist_password
    end
    ##if user isnt an archivist make it so
    unless u.is_archivist?
      u.roles << Role.find_by_name("archivist")
      u.save
    end
    @archivist_user_id = u.id
    ##ensure user is activated
    if @check_archivist_activated
      unless u.activated_at
        u.activate
      end
    end
    ## make the collection if it doesn't exist already
    c = Collection.find_or_initialize_by_name(@new_collection_name)
    if c.new_record?
      c.description = @new_collection_description
      c.title = @new_collection_title
    end
    ## add the user as an owner if not already one
    unless c.owners.include?(u.default_pseud)
      p = c.collection_participants.where(:pseud_id => u.default_pseud.id).first || c.collection_participants.build(:pseud => u.default_pseud)
      p.participant_role = "Owner"
      c.save
      p.save
    end
    c.save

    @new_collection_id = c.id
    puts "Archivist #{u.login} set up and owns collection #{c.name}."
    if @categories_as_sub_collections
      puts "Creating sub collections"
      convert_categories_to_collections(0)
    end
  end

  #add chapters    takes chapters and adds them to import work object  , takes Work, old_work_id
  # @param [Work]  new_work
  # @param [integer] old_work_id
  # @param [true/false] first if is first call ie, add first chapter only
  # @return [work] returns work object with chapters added, already saved if first = false
  def add_chapters(new_work, old_work_id, first)
    begin
      case @source_archive_type
        when 4 #Storyline
               #TODO Update to follow syntax of condition 3 below
          puts "1121 == Select * from #{@source_chapters_table} where csid = #{old_work_id}"
          r = @connection.query("Select * from #{@source_chapters_table} where csid = #{old_work_id}")
          puts "333"
          ix = 1
          r.each do |rr|
            c = new_work.chapters.build
            #c.new_work_id = ns.new_work_id     will be made automatically
            #c.pseud_id = ns.pseuds[0]
            c.title = rr[1]
            c.created_at = rr[4]
            #c.updated_at = rr[4]
            c.content = rr[3]
            c.position = ix
            c.summary = ""
            c.posted = 1
            #ns.chapters << c
            ix = ix + 1
            #self.post_chapters(c, @source_archive_type)
          end
        when 3 #efiction 3
          if first
            query = "Select chapid,title,inorder,notes,storytext,endnotes,sid,uid from  #{@source_chapters_table} where sid = #{old_work_id} order by inorder asc Limit 1"
          else
            first_chapter_index = get_single_value_target("Select inorder from  #{@source_chapters_table} where sid = #{old_work_id} order by inorder asc Limit 1")
            query = "Select chapid,title,inorder,notes,storytext,endnotes,sid,uid from  #{@source_chapters_table} where sid = #{old_work_id} and inorder  > #{first_chapter_index} order by inorder asc"
          end
          r = @connection.query(query)
          puts " chaptercount #{r.num_rows} "
          position_holder = 2
          r.each do |rr|
            if first
              c = new_work.chapters.build()
              c.position = 1
            else
              c = new_work.chapters.new
              c.work_id = new_work.id
              c.authors = new_work.authors
              c.position = position_holder
            end
            c.title = rr[1]
            #c.created_at  = rr[4]
            #c.updated_at = rr[4]
            ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
            valid_string = ic.iconv(rr[4] + ' ')[0..-2]
            c.content = valid_string
            c.summary = rr[3]
            c.posted = 1
            c.published_at = Date.today
            c.created_at = Date.today
            unless first
              c.save!
              new_work.save
              ##get reviews for all chapters but chapter 1, all chapter 1 reviews done in separate step post work import
              ##due to the chapter not having an id until the work gets saved for the first time
              import_chapter_reviews(rr[0], c.id)
            end
          end
        else
          puts "Error: (add_chapters): Invalid source archive type"
      end

      return new_work
    rescue Exception => ex
      puts "error in add chapters : #{ex}"
    end

  end

  #adds new creatorship, takes creationid, creation type, pseud_id
  # @param [integer]  creation_id
  # @param [string] creation_type
  # @param [integer] pseud_id
  # @return [integer] new_creatorship.id
  def add_new_creatorship(creation_id, creation_type, pseud_id)
    begin
      new_creation = Creatorship.new()
      new_creation.creation_type = creation_type
      new_creation.pseud_id = pseud_id
      new_creation.creation_id = creation_id
      new_creation.save!
      puts "New creatorship #{new_creation.id}"
      return new_creation.id
    rescue Exception => ex
      puts "error in add new creatorship #{ex}"
      return 0
    end
  end

  #take tag from mytaglist and add to taggings
  # @param [integer] work_id
  # @param [ImportTag] new_tag
  def add_work_taggings(work_id, new_tag)
    begin
      my_tagging = Tagging.new
      puts "looking for tag with name #{new_tag.tag}"
      temp_tag = Tag.new
      temp_tag = Tag.find_by_name(new_tag.tag)
      unless temp_tag.name == nil
        puts "found tag with name #{temp_tag.name} and id #{temp_tag.id}"
        my_tagging.taggable_id = work_id
        my_tagging.tagger = temp_tag
        my_tagging.taggable_type="Work"
        my_tagging.save!
      end
    rescue Exception => ex
      puts "error add work taggings #{ex}"
    end
  end

  #Add User, takes ImportUser
  # @param [ImportUser]  a   ImportUser object to add
  def add_user(a)
    begin
      email_array = a.email.split("@")
      login_temp = email_array[0] #take first part of email
      login_temp = login_temp.tr(".", "") # remove any dots
      login_temp = "i#{@archive_import_id}#{login_temp}" #prepend archive id
      new_user = User.new()
      new_user.terms_of_service = "1"
      new_user.email = a.email
      new_user.login = login_temp
      new_user.password = a.password
      #below line might not be needed
      new_user.password_confirmation = a.password
      new_user.age_over_13 = "1"
      new_user.save!
      ##Create Default Pseud / Profile
      new_user.create_default_associateds
      a.new_user_id = new_user.id
      return a
    rescue Exception => e
      puts "error 1010: #{e}"
    end
  end

  # Set Archive Strings and values basedo on archive type, based on the predinined values used
  # with the particular source archive software
  def set_import_strings(source_archive_type)
    case source_archive_type
      when 1 ## efiction 1
        @source_chapters_table = "#{@temp_table_prefix}#{@source_table_prefix}chapters"
        @source_reviews_table = "#{@temp_table_prefix}#{@source_table_prefix}reviews"
        @source_stories_table = "#{@temp_table_prefix}#{@source_table_prefix}stories"
        @source_categories_table = "#{@temp_table_prefix}#{@source_table_prefix}categories"
        @source_users_table = "#{@temp_table_prefix}#{@source_table_prefix}authors"
        @source_characters_table = "#{@temp_table_prefix}#{@source_table_prefix}characters"
        @source_warnings_table = "#{@temp_table_prefix}#{@source_table_prefix}warnings"
        @source_generes_table = "#{@temp_table_prefix}#{@source_table_prefix}generes"
        @source_author_query = " "
      when 2 ## efiction2
        @source_chapters_table = "#{@temp_table_prefix}#{@source_table_prefix}chapters"
        @source_reviews_table = "#{@temp_table_prefix}#{@source_table_prefix}reviews"
        @source_stories_table = "#{@temp_table_prefix}#{@source_table_prefix}stories"
        @source_characters_table = "#{@temp_table_prefix}#{@source_table_prefix}characters"
        @source_warnings_table = "#{@temp_table_prefix}#{@source_table_prefix}warnings"
        @source_generes_table = "#{@temp_table_prefix}#{@source_table_prefix}generes"
        @source_users_table = "#{@temp_table_prefix}#{@source_table_prefix}authors"
        @source_author_query = "Select realname, penname, email, bio, date, pass, website, aol, msn, yahoo, icq, ageconsent from  #{@source_users_table} where uid ="

      when 3 ## efiction3
        @source_chapters_table = "#{@temp_table_prefix}#{@source_table_prefix}chapters"
        @source_reviews_table = "#{@temp_table_prefix}#{@source_table_prefix}reviews"
        @source_challenges_table = "#{@temp_table_prefix}#{@source_table_prefix}challenges"
        @source_stories_table = "#{@temp_table_prefix}#{@source_table_prefix}stories"
        @source_categories_table = "#{@temp_table_prefix}#{@source_table_prefix}categories"
        @source_characters_table = "#{@temp_table_prefix}#{@source_table_prefix}characters"
        @source_series_table = "#{@temp_table_prefix}#{@source_table_prefix}series"
        @source_inseries_table = "#{@temp_table_prefix}#{@source_table_prefix}inseries"
        @source_ratings_table = "#{@temp_table_prefix}#{@source_table_prefix}ratings"
        @source_classes_table = "#{@temp_table_prefix}#{@source_table_prefix}classes"
        @source_class_types_table = "#{@temp_table_prefix}#{@source_table_prefix}class_types"
        @source_users_table = "#{@temp_table_prefix}#{@source_table_prefix}authors"
        @source_author_query = "Select realname, penname, email, bio, date, password from #{@source_users_table} where uid ="

      when 4 ## storyline
        @source_chapters_table = "#{@temp_table_prefix}#{@source_table_prefix}chapters"
        @source_reviews_table = "#{@temp_table_prefix}#{@source_table_prefix}reviews"
        @source_stories_table = "#{@temp_table_prefix}#{@source_table_prefix}stories"
        @source_users_table = "#{@temp_table_prefix}#{@source_table_prefix}users"
        @source_categories_table = "#{@temp_table_prefix}#{@source_table_prefix}category"
        @source_subcategories_table = "#{@temp_table_prefix}#{@source_table_prefix}subcategory"
        @source_hitcount_table = "#{@temp_table_prefix}#{@source_table_prefix}rating"
        @source_ratings_table = nil #None
        @source_author_query = "SELECT urealname, upenname, uemail, ubio, ustart, upass, uurl, uaol, umsn, uicq from #{@source_users_table} where uid ="

      when 5 ## otwarchive
        @source_users_table = "#{@temp_table_prefix}#{@source_table_prefix}users"
      else
        puts "Error: (set_import_settings): Invalid source archive type"
    end
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

# Consolidate Author Fields into User About Me String, takes Import User
# @param [importuser]  a
  def build_bio(a)
    if a.yahoo == nil
      a.yahoo = " "
    end
    if a.aol.length > 1 || a.yahoo.length > 1 || a.website.length > 1 || a.icq.length > 1 || a.msn.length > 1
      if a.bio.length > 0
        a.bio << "<br /><br />"
      end
    end
    if a.aol.length > 1
      a.bio << " <br /><b>AOL / AIM :</b><br /> #{a.aol}"
    end
    if a.website.length > 1
      a.bio << "<br /><b>Website:</ b><br /> #{a.website}"
    end
    if a.yahoo.length > 1
      a.bio << "<br /><b>Yahoo :</b><br /> #{a.yahoo}"
    end
    if a.msn.length > 1
      a.bio << "<br /><b>Windows Live:</ b><br /> #{a.msn}"
    end
    if a.icq.length > 1
      a.bio << "<br /><b>ICQ :</b><br /> #{a.icq}"
    end
    return a
  end

  ####Reserved####
  ##gets the collections that the work is supposed to be in based on old cat id's
  ##note: until notice, this function will not be used.
  def get_work_collections(collection_string)
    temp_string = collection_string
    temp_array = Array.new
    collection_string = temp_string.split(",")
    collection_string.each do |c|
      new_collection_id = get_single_value_target("Select new_id from collection_imports where source_archive_id = #{@archive_import_id} AND old_id = #{c} ")
      temp_collection = Collection.find(new_collection_id)
      temp_array.push(temp_collection)
    end
    #collection_string = temp_array
    return temp_array
  end

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
          else
            ##shouldnt happen
            #TODO EXIT FUNCTION LOG ERROR
        end

    end
  end

  ####
  #used with efiction 3 archives to get values to be gotten as tags
  # @param [array] tl import tag array
  # @param [string] class_str
  # @param [string]  my_type tag type
  def get_source_work_tags(tl, class_str, my_type)
    query = ""
    new_tag_type = ""
    #class_split = Array.new
    class_split = class_str.split(",")
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

  #return old new id from user_imports table based on old user id & source archive
  # @param [integer]  old_id
  # @param [integer]  source_archive
  def get_new_user_id_from_imported(old_id, source_archive)
    puts "#{old_id}"
    return get_single_value_target("select user_id from user_imports where source_user_id = #{old_id} and source_archive_id = #{source_archive}")
  end

  #get default pseud given userid
  # @param [integer]  user_id
  def get_default_pseud_id(user_id)
    return get_single_value_target("select id from pseuds where user_id = #{user_id}")
  end

  #given valid user_id search for psued belonging to that user_id with matching penname
  def get_pseud_id_for_penname(user_id, penname)
    puts "11-#{user_id}-#{penname}"
    return get_single_value_target("select id from pseuds where user_id = #{user_id} and name = '#{penname}'")
  end

  def get_new_work_id_fresh(source_work_id, source_archive_id)
    puts "13-#{source_work_id}~~#{source_archive_id}"
    return get_single_value_target("select id from works where imported_from_url = '#{source_work_id}~~#{source_archive_id}'")
  end

  # Return new story id given old id and archive
  def get_new_work_id_from_old_id(source_archive_id, old_work_id) #
    puts "12-#{source_archive_id}-#{old_work_id}"
    return get_single_value_target(" select work_id from work_imports where source_archive_id #{source_archive_id} and old_work_id=#{old_work_id}")
  end

  # Get New Author ID from old User ID & old archive ID
  def get_new_author_id_from_old(old_archive_id, old_user_id)
    return get_single_value_target(" Select user_id from user_imports where source_archive_id = #{old_archive_id} and source_user_id = #{old_user_id} ")
  end

  #check for existing user by email address, returns id
  def get_user_id_from_email(emailaddress)
    return get_single_value_target("select id from users where email = '#{emailaddress}'")
  end

  #query and return a single value from database
  # @param [string] query
  # @return [string or integer] if no result found returns 0
  def get_single_value_target(query)
    begin
      connection = Mysql.new(@database_host, @database_username, @database_password, @database_name)
      r = connection.query(query)
      if r.num_rows == 0
        return 0
      else
        r.each do |rr|
          return rr[0]
        end
      end
    rescue Exception => ex
      connection.close()
      puts ex.message
      puts "Error with #{query} : get_single_value_target"
    end
  end

  # Update db record takes query as peram (any non returning query)
  # @param [string] query
  def update_record_target(query)
    begin
      connection2 = Mysql.new(@database_host, @database_username, @database_password, @database_name)
      rowsEffected = 0
      rowsEffected = connection2.query(query)
      connection2.close
      return rowsEffected
    rescue Exception => ex
      connection2.close()
      puts ex.message
      puts "Error with #{query} : update_record_target"
      return 0
    ensure
    end
  end

#take the settings from the form and pass them into the internal instance specific variables
#for the mass import object.
  def populate(settings)
    ## database values
    @database_host = settings[:database_host]
    @database_name = settings[:database_name]
    @database_password = settings[:database_password]
    @database_username = settings[:database_username]
    @source_table_prefix = settings[:source_table_prefix]
    ## define temp value for temp appended prefix for table names
    @temp_table_prefix = "ODimport"
    if !settings[:temp_table_prefix] == nil
      @temp_table_prefix = settings[:temp_table_prefix]
    end
    ## archivist values
    @archivist_email = settings[:archivist_email]
    @archivist_login = settings[:archivist_username]
    @archivist_password = settings[:archivist_password]
    ## import values
    @import_fandom = settings[:import_fandom]
    @import_name = settings[:import_name]
    @import_id = settings[:import_id]
    @import_reviews = settings[:import_reviews]
    @categories_as_sub_collections = settings[:categories_as_sub_collections]
    ## collection values
    @create_collection = settings[:create_collection]
    @new_collection_description = settings[:new_collection_description]
    @new_collection_id = settings[:new_collection_id]
    @new_collection_name = settings[:new_collection_short_name]
    @new_collection_owner = settings[:new_collection_owner]
    @new_collection_title = settings[:new_collection_title]
    @new_collection_restricted = settings[:new_collection_restricted]
    ## notification values
    @new_notification_message = settings[:new_message]
    @existing_notification_message = settings[:existing_message]

    case settings[:archive_type]
      when "efiction3"
        @source_archive_type = 3
      when "storyline18"
        @source_archive_type = 4
      when "efiction1"
        @source_archive_type = 1
      when "efiction2"
        @source_archive_type = 2
      when "otwarchive"
        @source_archive_type = 5

    end

    ## Overrides for abnormal / non-typical imports (advanced use only)
    if settings[:override_tables] == 1
      @source_users_table = settings[:source_users_table]
      @source_chapters_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_chapters_table]}"
      @source_reviews_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_reviews_table]}"
      @source_stories_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_stories_table]}"
      @source_users_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_users_table]}"
      @source_categories_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_category_table]}"
      @source_subcategories_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_subcategory_table]}"
      @source_ratings_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_ratings_table]}"
      @source_classes_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_classes_table]}"
      @source_class_types_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_class_types_table]}"
      @source_warnings_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_warnings_table]}"
      @source_characters_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_characters_table]}"
      @source_challenges_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_challenges_table]}"
      @source_collections_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_collections_table]}"
      @source_hitcount_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_hitcount_table]}"
      @source_user_preferences_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_user_preferences_table]}"
      @source_user_profile_fields_table ="#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_user_profiles_fields_table]}"
      @source_user_profile_values_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_user_profiles_values_table]}"
      @source_user_profiles_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_user_profiles_table]}"
      @source_pseuds_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_pseuds_table]}"
      @source_collection_items_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_collection_items_table]}"
      @source_collection_participants_table = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_collection_participants]}"
      ## other possible source tables to be added here

    end
    if settings[:override_target_ratings] == 1
      @target_rating_1 = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_target_rating_1]}" #NR
      @target_rating_2 = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_target_rating_2]}" #general audiences
      @target_rating_3 = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_target_rating_3]}" #teen
      @target_rating_4 = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_target_rating_4]}" #Mature
      @target_rating_5 = "#{@temp_table_prefix}#{@source_table_prefix}#{settings[:source_target_rating_5]}" #Explicit
    end
    ## initialize database connection object
    @connection = Mysql.new(@database_host, @database_username, @database_password, @database_name)
  end

  #file operations
  #create archive directory
  # @param [string] directory to check for existance and create
  def check_create_dir(import_path)
    unless File.directory?(import_path)
      `mkdir #{import_path}`
    end
  end

  #move uploaded files, unzip them, transform the sql file, save it, execute it
  def run_file_operations
    check_create_dir(@import_files_path)
    `mv /tmp/#{@sql_filename} #{@import_files_path}`
    `unzip #{@import_files_path}/#{@sql_filename} -d #{@import_files_path}`
    transform_source_sql()
    load_source_db()
    begin
      if @archive_has_chapter_files
        `mv /tmp/#{@archive_chapters_filename} #{@import_files_path}`
        `unzip #{@import_files_path}/#{@archive_chapters_filename} -d #{@import_files_path}`
        #add the content to the chapters in the database
        update_source_chapters
      end
    rescue Exception => ex
      puts "error in file opperations 2 #{ex}"
    end
  end

  # File actionpack/lib/action_view/helpers/text_helper.rb, line 266
  def simple_format(text, html_options={}, options={})
    text = '' if text.nil?
    text = text.dup
    start_tag = tag('p', html_options, true)
    text = sanitize(text) unless options[:sanitize] == false
    text = text.to_str
    text.gsub!(/\r\n?/, "\n") # \r\n and \r -> \n
    text.gsub!(/\n\n+/, "</p>\n\n#{start_tag}") # 2+ newline  -> paragraph
    text.gsub!(/([^\n]\n)(?=[^\n])/, '\1<br />') # 1 newline   -> br
    text.insert 0, start_tag
    text.html_safe.safe_concat("</p>")
  end

  #update each record in source db reading the chapter text file importing it into content field
  def update_source_chapters
    ## select source chapters from database
    rr = @connection.query("Select distinct uid from #{@source_chapters_table}")
    rr.each do |r3|
      pathname = "#{@import_files_path}/stories/#{r3[0]}"
      Dir.foreach(pathname) do
      |f|
        next if f == ".."
        next if f == "."
        chapter_content = read_file_to_string("#{@import_files_path}/stories/#{r3[0]}/#{f}")
        #chapter_content = Nokogiri::HTML.parse(chapter_content, nil, encoding) rescue ""
        #chapter_content = simple_format(chapter_content)
        chapter_content = Mysql.escape_string(chapter_content)
        #ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
        # chapter_content = ic.iconv(chapter_content + ' ')[0..-2]
        ## update the source chapter record
        chapterid = f.gsub(".txt", "")
        puts "reading chapter: #{chapterid}"
        update_record_target("update #{@source_chapters_table} set storytext = \"#{chapter_content}\" where chapid = #{chapterid}")
      end

    end
    puts "6a) Source Chapter Data Reconstructed"
  end

  #read a file to a string
  # @param [string] filename
  def read_file_to_string(filename)
#    file_path = "#{@import_files_path}/#{filename}"
    text = File.read(filename)
    return text
  end

  #save string to file
  # @param [string] string
  # @param [string] filename
  def save_string_to_file(string, filename)
    File.open(filename, 'w') { |f| f.write(string) }
  end

  def format_chapters(workid)
    rr = @connection.query("Select id from chapters where work_id = #{workid}")
    rr.each do |row|
      c = Chapter.find(row[0])
      c.content = simple_format(c.content)
      c.save!
    end

  end

  #process source db sql file and save
  def transform_source_sql
    sql_file = read_file_to_string("#{@import_files_path}/#{@sql_filename}")
    ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
    valid_string = ic.iconv(sql_file + ' ')[0..-2]
    sql_file = valid_string
    sql_file = sql_file.gsub("TYPE=MyISAM", "")
    sql_file = sql_file.gsub(@source_table_prefix, "#{@temp_table_prefix}#{@source_table_prefix}")
    save_string_to_file(sql_file, "#{@import_files_path}/data_clean.sql")
  end

  #load cleaned source db file into mysql
  def load_source_db
    `mysql -u #{@database_username} -p#{@database_password} #{@database_name} < #{@import_files_path}/data_clean.sql`
  end


=begin

  #Post Chapters Fix
  def post_chapters2(c, sourceType)
    begin
      case sourceType
        when 4 #storyline
          new_c = Chapter.new
          new_c.work_id = c.new_work_id
          new_c.created_at = c.date_posted
          new_c.updated_at = c.date_posted
          new_c.posted = 1
          new_c.position = c.position
          new_c.title = c.title
          new_c.summary = c.summary
          new_c.content = c.body
          new_c.save!
          puts "New chapter id #{new_c.id}"
          add_new_creatorship(new_c.id, "Chapter", c.pseud_id)
        when 3 #efiction
          new_c = Chapter.new
          new_c.work_id = c.new_work_id
          new_c.created_at = c.date_posted
          new_c.updated_at = c.date_posted
          new_c.posted = 1
          new_c.position = c.position
          new_c.title = c.title
          new_c.summary = c.summary
          new_c.content = c.body
          new_c.save!
          add_new_creatorship(new_c.id, "Chapter", c.pseud_id)

      end
    rescue Exception => ex
      puts "error in post chapters 2 #{ex}"
    end

  end
=end
=begin


  def add_chapters2(ns, new_id, old_id)
    query = ""
    begin
      case @source_archive_type
        when 4
          puts "1121 == Select * from #{@source_chapters_table} where csid = #{old_id} order by id asc"
          query = "Select * from #{@source_chapters_table} where csid = #{old_id}"
          r = @connection.query(query)
          puts "333"

          ix = 1
          r.each do |rr|
            c = ImportChapter.new()
            c.new_work_id = new_id

            c.title = rr[1]
            c.date_posted = rr[4]
            c.body = rr[3]
            c.position = ix
            self.post_chapters2(c, @source_archive_type)
          end
        when 3
          query="Select chapid,title,inorder,notes,storytext,endnotes,sid,uid from #{@source_chapters_table} where sid = #{old_id}"
          puts query
          r = @connection.query(query)
          puts "333 #{r.num_rows}"

          r.each do |rr|
            c = ImportChapter.new()
            #c.new_work_id = ns.new_work_id     will be made automatically
            #c.pseud_id = ns.pseuds[0]
            c.title = rr[1]
            #c.created_at  = rr[4]
            #c.updated_at = rr[4]
            c.body = rr[4]
            c.position = rr[2]
            c.summary = rr[3]

            #ns.chapters << c
            self.post_chapters2(c, @source_archive_type)
          end


      end
    rescue Exception => ex
      puts " Error : " + ex.message
      puts "query = #{query}"


    end
  end
=end

end