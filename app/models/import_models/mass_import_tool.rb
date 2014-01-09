# encoding=utf-8
# Mass Import Tool
# Questions? Ask Stephanie =)
class MassImportTool
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::TagHelper #tag_options needed by auto_link
  require 'mysql2'
  require 'mysql'

  def initialize
    #Import Class Version Number
    @version = 1
    @ih = ImportHelper.new
    @post_url = "http://stephanies.archiveofourown.org/works/import"
    @use_new_mysql = 0
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

    #TODO NOTE! change to nil for final version, as there will be no default
    @connection = nil
    if @use_new_mysql == 0 then
      @connection = Mysql.new(@database_host, @database_username, @database_password, @database_name)
    else
      @connection = Mysql2::Client.new(:host => @database_host, :username => @database_username, :password => @database_password, :database => @database_name)
    end


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

    #Default Language for imported works
    @default_language = Language.find_by_short("en")

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
    #bypass check to see if existing
    @rerun_import = 0

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



  def post_story
    HTTParty.post(@post_url,
      :query => {
          :email => "alan+thinkvitamin@carsonified.com",
          :email => "alan+thinkvitamin@carsonified.com",
          :email => "alan+thinkvitamin@carsonified.com",
          :email => "alan+thinkvitamin@carsonified.com",
          :email => "alan+thinkvitamin@carsonified.com",
          :email => "alan+thinkvitamin@carsonified.com",
          :email => "alan+thinkvitamin@carsonified.com",
          :email => "alan+thinkvitamin@carsonified.com",
          :email => "alan+thinkvitamin@carsonified.com",
          :email => "alan+thinkvitamin@carsonified.com",

      },

      :headers => { "Authorization" => "THISISMYAPIKEYNOREALLY"
      }
    )
  end
  ##################################################################################################
  # Main Worker Sub
  def import_data
    puts "1) Setting Import Values"
    self.set_import_strings(@source_archive_type)
    self.create_archivist_and_collection
    self.create_import_record
    @import_files_path = "#{Rails.root.to_s}/imports/#{@archive_import_id}"
    puts "2) Running File Operations"
    run_file_operations
    puts "3) Updating Tags"
    source_archive_tag_list = Array.new()
    ## create list of all tags used in source
    source_archive_tag_list = get_tag_list(source_archive_tag_list)
    ## check for tag existance on target archive
    source_archive_tag_list = self.fill_tag_list(source_archive_tag_list)

    ## pull source stories from database to array of rows
    r = @connection.query("SELECT * FROM #{@source_stories_table} ;")
    puts "4) Importing Stories"
    i = 0
    r.each do |row|
      puts " Importing Story ID#{row[0]}"
      #Check to ensure work hasnt already been imported for this import run / archive
      #ignored if rerun_import  = 1
      if @rerun_import == 0
        temp_work_import = WorkImport.find_by_source_archive_id_and_source_work_id(@archive_import_id, row[0])
        # if puts msg isnt important could use next if as done below when checking for presence of chapters
        if temp_work_import.empty? || temp_work_import == nil
          puts "##### Story Previously Imported For This Archive #####"
          next
        end
      end

      ns = ImportWork.new()
      import_user = ImportUser.new()

      ## Create Taglisit for this story
      ns.tag_list =  Array.new()

      ## assign data to import work object
      ns = ImportWork.new
      ns = assign_row_import_work(ns, row)
      ns.tag_list

      ## goto next if no chapters
      num_source_chapters = 0
      num_source_chapters = get_single_value_target("Select chapid  from #{@source_chapters_table} where sid = #{ns.old_work_id} limit 1")
      next if num_source_chapters == 0

      ## see if user / author exists for this import already
      user_import = UserImport.find_by_source_user_id_and_source_archive(old_id,@archive_import_id)

      if user_import != nil
        ns.new_user_id = user_import.id
      end
      ## get import user object from source database
      import_user = self.get_import_user_object_from_source(ns.old_user_id)
      if user_import == nil
        ns.new_user_id = 0
        puts "user didnt exist in this import session"
        ## see if user account exists in main archive by checking email,
        temp_user_object = User.find_by_email(import_user.email)

        if temp_user_object == nil
          ## if not exist , add new user with user object, passing old author object
          import_user = ImportUser.new
          import_user = self.add_user(import_user)
          ## pass values to new story object
          ns.penname = import_user.penname
          ns.new_user_id = import_user.new_user_id
          ## debug info
          puts "newid = #{import_user.new_user_id}"
          ## get newly created pseud id
          new_pseud_id = get_default_pseud_id(ns.new_user_id)
          ## set the penname on newly created pseud to proper value
          update_record_target("update pseuds set name = '#{ns.penname}' where id = #{new_pseud_id}")
          ## create user import


          #create_user_import(import_user.new_user_id, new_pseud_id, ns.old_user_id, @archive_import_id)
          ns.new_pseud_id = new_pseud_id
        else
          ## user exists, but is being imported
          ## insert the mapping value
          puts "Debug: User existed in Target Archive"
          ns.penname = import_user.penname
          ## check to see if penname exists as pseud for existing user
          temp_pseud_object = Pseud.find_by_user_id_and_name(temp_user_object.id,ns.penname)
          #temp_pseud_id = get_pseud_id_for_penname(temp_author_object.id, ns.penname)
          if temp_pseud_object == nil
            ## add pseud if not exist
            temp_pseud_object = create_new_pseud(temp_user_object.id, import_user.penname, true, "Imported")
            ns.new_pseud_id = temp_pseud_object.id
            ## create USER IMPORT
            create_user_import(temp_user_object.id, temp_pseud_object.id, ns.old_user_id, @archive_import_id)
            # 'temp_pseud_id = get_pseud_id_for_penname(ns.new_user_id,ns.penname)
            #todo edit out
            update_record_target("update user_imports set pseud_id = #{temp_pseud_object.id} where user_id = #{ns.new_user_id} and source_archive_id = #{@archive_import_id}")
            ns.new_user_id = temp_pseud_object.id
            import_user.pseud_id = temp_pseud_object.id
          end
        end
      else
        ns.penname = import_user.penname
        import_user.pseud_id = get_pseud_id_for_penname(ns.new_user_id, ns.penname)
        puts "#{import_user.pseud_id} this is the matching pseud id"
        ns.new_pseud_id = import_user.pseud_id
      end
      ## insert work object
      new_work = prepare_work(ns)
      # todo investigate why i was checking length < 5 , steph
      next if new_work.chapters[0].content.length < 5
      new_work.save!
      add_chapters(new_work, ns.old_work_id, false)

      ## add all chapters to work
      new_work.expected_number_of_chapters = new_work.chapters.count
      new_work.save

      puts "Taglist count = #{ns.tag_list.count}"
      ns.tag_list.each do |t|
        add_work_taggings(new_work.id, t)
      end

      ## save first chapter reviews since cand do it in addchapters like rest
      old_first_chapter_id = get_single_value_target("Select chapid from  #{@source_chapters_table} where sid = #{ns.old_work_id} order by inorder asc Limit 1")
      import_chapter_reviews(old_first_chapter_id, new_work.chapters.first.id)

      create_new_work_import(new_work, ns, @archive_import_id)
      format_chapters(new_work.id)
      i = i + 1
    end
    ## import series
    import_series
    @connection.close()

  end


  ##############################################################
  ## Tags
  ##############################################################

  #take tag from mytaglist and add to taggings
  # @param [integer] work_id
  # @param [ImportTag] new_tag
  def add_work_taggings(work_id, new_tag)
    begin
      my_tagging = Tagging.new
      my_tagging.taggable_type="Work"

      puts "looking for tag with name #{new_tag.tag}"
      temp_tag = Tag.new
      temp_tag = Tag.find_by_name(new_tag.tag)
      unless temp_tag.name == nil
        puts "found tag with name #{temp_tag.name} and id #{temp_tag.id}"
        my_tagging.taggable_id = work_id
        my_tagging.tagger = temp_tag

        my_tagging.save!
      end
    rescue Exception => ex
      puts "error add work taggings #{ex}"
    end
  end


  #ensure all source tags exist in target in some form
  #uses array of ImportTag created from get_tag_list
  def fill_tag_list(tag_list)
    i = 0
    while i <= tag_list.length - 1
      temp_tag = tag_list[i]
      temp_new_tag = Tag.new()

      #check for tag presence at destination
      lookup_tag = Tag.find_by_name(temp_tag.tag)
      if lookup_tag != nil
        temp_tag.new_id = lookup_tag.id
      else
        #Create new tag
        temp_new_tag.name = "#{temp_tag.tag}"
        if !temp_tag.tag_type == "Category" || 99
          temp_new_tag.type = "#{temp_tag.tag_type}"
        else
          if @categories_as_tags
            temp_new_tag.type = "Freeform"
          end
        end
        temp_new_tag.save
        temp_tag.new_id = temp_new_tag.id
      end

      ## return importtag object with new id and its corresponding data ie old id and tag to array
      tag_list[i] = temp_tag
      i = i + 1
    end
    return tag_list
  end



  ##############################################################
  ## collections
  ##############################################################

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





  ##############################################################
  ## Users
  ##############################################################



  #Add User, takes ImportUser
  # @param [ImportUser]  import_user   ImportUser object to add
  def add_user(import_user)
    begin
      email_array = import_user.email.split("@")
      login_temp = email_array[0] #take first part of email
      login_temp = login_temp.tr(".", "") # remove any dots
      login_temp = "i#{@archive_import_id}#{login_temp}" #prepend archive id
      new_user = User.new()
      new_user.terms_of_service = "1"
      new_user.email = import_user.email
      new_user.login = login_temp
      new_user.password = import_user.password
                                  #below line might not be needed
      new_user.password_confirmation = import_user.password
      new_user.age_over_13 = "1"
      new_user.save!
                                  ##Create Default Pseud / Profile
      new_user.create_default_associateds
      import_user.new_user_id = new_user.id
      return import_user
    rescue Exception => e
      puts "error 1010: #{e}"
    end
  end

  #create user import
  # Note: changed to pass archive_import_id into method instead of using class instance var, Stephanie 9-18-2013
  # @param [integer] author_id
  # @param [integer] pseud_id
  # @param [integer] old_user_id
  # @param [integer] archive_import_id
  def create_user_import(author_id, pseud_id, old_user_id, archive_import_id)
    begin
      new_ui = UserImport.new
      new_ui.user_id = author_id
      new_ui.pseud_id = pseud_id
      new_ui.source_user_id = old_user_id
      new_ui.source_archive_id = archive_import_id
      new_ui.save!
      return new_ui.id
    rescue Exception => e
      puts "Error: 777: function create_user_import #{e}"
      return 0
    end
  end

  ##############################################################
  ## Work
  ##############################################################


  #Create work and return once saved, takes ImportWork
  # @return [Work] returns newly created work object
  # @param [ImportWork]  import_work
  def prepare_work(import_work)
    new_work = Work.new
    new_work.title = import_work.title
    new_work.summary = import_work.summary

    puts "Title to be = #{new_work.title}"
    puts "summary to be = #{new_work.summary}"

    new_work.authors_to_sort_on = import_work.penname
    new_work.title_to_sort_on = import_work.title
    new_work.restricted = true
    new_work.posted = true
    puts "looking for pseud #{import_work.new_pseud_id}"
    #new_work.pseuds << Pseud.find_by_id(import_work.new_pseud_id)
    #todo ensure handles multiple authors , steph - 9-15-2013
    new_work.authors = [Pseud.find_by_id(import_work.new_pseud_id)]
    new_work.revised_at = Date.today
    new_work.created_at = Date.today
    new_work.revised_at = import_work.updated
    new_work.created_at = import_work.published

    puts "revised = #{new_work.revised_at}"
    puts "crated at  = #{new_work.created_at}"
    new_work.fandom_string = @import_fandom

    #todo finish rating code assignment, steph, 9-15-2013
    new_work.rating_string = "Not Rated"
    new_work.warning_strings = "None"
    puts "old work id = #{import_work.old_work_id}"
    #todo - see if there is a better way other then setting the value here, may be redundant, steph 9-15-2013
    new_work.imported_from_url = "#{@archive_import_id}~~#{import_work.old_work_id}"

    new_work.language = @default_language
    new_work = add_chapters(new_work, import_work.old_work_id, true)

    ##assign to main import collection
    new_work.collections << Collection.find(@new_collection_id)

    return new_work
  end

  #Create new work import, takes Work , ImportWork
  # @param [work] new_work
  # @param [importwork] ns
  # @param [integer] source_archive_id
  def create_new_work_import(new_work, ns, source_archive_id)
    begin
      new_wi = WorkImport.new
      new_wi.work_id = new_work.id
      new_wi.pseud_id = ns.new_user_id
      new_wi.source_archive_id = source_archive_id
      new_wi.source_work_id = ns.old_work_id
      new_wi.source_user_id = ns.old_user_id
      new_wi.save!
      return new_wi.id
    rescue Exception => e
      puts "Error in function create_new_work import: #{e}"
      return 0
    end
  end

  ##############################################################
  ## Series / Serial Works
  ##############################################################


  #import series objects
  #todo make extensible in future for other archive types ala case statement.  low priority - stephanie, 9-18-2013
  def import_series
    #create the series objects in new archive
    r = @connection.query("Select seriesid,title,summary,uid,rating,classes,characters, isopen from #{@source_series_table}")
    if r.count >= 1
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


  #copied and modified from mass import rake, stephanies 1/22/2012
  #Create archivist and collection if they don't already exist"
  def create_archivist_and_collection

    ## make the archivist user if it doesn't exist already
    u = User.find_or_initialize_by_login(@archivist_login)
    if u.new_record?
      u.password = @archivist_password
      u.email = @archivist_email
      u.age_over_13 = "1"
      u.terms_of_service = "1"
      #below line might not be needed
      u.password_confirmation = @archivist_password
    end
    unless u.is_archivist?
      u.roles << Role.find_by_name("archivist")
      u.save
    end
    @archivist_user_id = u.id
    if @check_archivist_activated
      unless u.activated_at
        u.activate
      end
    end
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
    ## return the collection id to class instance variable
    @new_collection_id = c.id
    puts "Archivist #{u.login} set up and owns collection #{c.name}."
=begin
    if @categories_as_sub_collections
      puts "Creating sub collections"
      @ih.convert_categories_to_collections(0)
    end
=end
  end

  ##############################################################
  ## Chapters
  ##############################################################


  #Function to return row count due to multi adapter
  def get_row_count(row_set)
    count_value = nil
    if @use_new_mysql == 0
      count_value = row_set.num_rows
    else
      count_value = row_set.count
    end
    return count_value
  end

  #import chapter reviews for efic 3 story takes old chapter id, new chapter id
  # updated multi adapter use 9-19-2013 Stephanie
  # @param [integer] old_chapter_id
  # @param [integer] new_chapter_id
  def import_chapter_reviews(old_chapter_id, new_chapter_id)
    r = @connection.query("Select reviewer, uid,review,date,rating from #{@source_reviews_table} where chapid=#{old_chapter_id}")

    count_value = get_row_count(r)

    #only run if we have reviews
    if count_value >=1
      r.each do |row|
        email = get_single_value_target("Select email from #{@source_users_table} where uid = #{row[1]}")
        create_chapter_comment(row[2], row[3], new_chapter_id, email, row[0], 0)
      end
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
          puts " chaptercount #{get_row_count(r)} "
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
              ## get reviews for all chapters but chapter 1, all chapter 1 reviews done in separate step post work import
              ## due to the chapter not having an id until the work gets saved for the first time
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

  ##############################################################
  ## New Wrappers
  ##############################################################

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


  #create import record
  # @return [integer]  import archive id
  def create_import_record
    # done- 9-18-2013 - update to use ar new method and save since is proper ar class now, make sure it returns new value after save - steph 9-9-13
    #update_record_target("insert into archive_imports (name,archive_type_id,old_base_url,associated_collection_id,new_user_notice_id,existing_user_notice_id,existing_user_email_id,new_user_email_id,new_url,archivist_user_id)  values ('#{@import_name}',#{@source_archive_type},'#{
    #@source_base_url}',#{@new_collection_id},#{@new_user_notice_id},#{@existing_user_notice_id},#{@new_user_email_id},#{@existing_user_email_id},'#{@new_url}',#{@archivist_user_id})")
    begin
      archive_import = ArchiveImport.new
      archive_import.name = @import_name
      archive_import.archive_type_id = @source_archive_type
      archive_import.old_base_url = @source_base_url
      archive_import.associated_collection_id = @new_collection_id
      archive_import.new_user_notice_id = @new_user_notice_id
      archive_import.new_user_email_id = @new_user_email_id
      archive_import.existing_user_email_id = @existing_user_email_id
      archive_import.existing_user_notice_id = @existing_user_notice_id
      archive_import.new_url = @new_url
      archive_import.archivist_user_id = @archivist_user_id
      archive_import.save!
      puts "record created"
      new_record = ArchiveImport.find_by_old_base_url(@source_base_url)

      return new_record.id
    rescue Exception => ex
      puts "error in add create archive import : #{ex}"
    end

  end

  #create new pseud  wrapper class
  # @param [integer] user_id
  # @param [string] penname
  # @param [true/false] default
  # @param [string] description
  # @return [pseud]  new pseud id
  def create_new_pseud(user_id, penname, default, description)
    begin
      new_pseud = Pseud.new
      new_pseud.user_id = user_id
      new_pseud.name = penname
      new_pseud.is_default = default
      new_pseud.description = description
      new_pseud.save!
      return new_pseud
    rescue Exception => e
      puts "Error: 111: #{e}"
      return new_pseud
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



  #get default pseud given userid
  #changed to ar 9-23-2013
  # @param [integer]  user_id
  def get_default_pseud_id(user_id)
    pseud = Pseud.find_by_user_id(user_id)
    return pseud.id
    #return get_single_value_target("select id from pseuds where user_id = #{user_id}")
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
  #updated to use ar 9-23-2013
  def get_new_work_id_from_old_id(source_archive_id, old_work_id) #
    puts "12-#{source_archive_id}-#{old_work_id}"
    work_import = WorkImport.find_by_old_wok_id_and_source_archive_id(old_work_id, source_archive_id)
    return work_import.work_id
    #return get_single_value_target(" select work_id from work_imports where source_archive_id #{source_archive_id} and old_work_id=#{old_work_id}")
  end

  # Get New Author ID from old User ID & old archive ID
  def get_new_author_id_from_old(old_archive_id, old_user_id)
    user_import = UserImport.find_by_old_user_id_and_source_archive_id(old_user_id,old_archive_id)
    return user_import.user_id
    #return get_single_value_target(" Select user_id from user_imports where source_archive_id = #{old_archive_id} and source_user_id = #{old_user_id} ")
  end

  #check for existing user by email address, returns id
  def get_user_id_from_email(emailaddress)
    return get_single_value_target("select id from users where email = '#{emailaddress}'")
  end

  # Updated to be able to use multiple gems
  #query and return a single value from database
  # @param [string] query
  # @return [string or integer] if no result found returns 0
  def get_single_value_target(query)
    begin
      r = nil
      connection = nil
      count_value = nil

      if @use_new_mysql == 0
        connection = Mysql.new(@database_host, @database_username, @database_password, @database_name)
        r = connection.query(query)

      else
        connection = Mysql2::Client.new(:host => @database_host, :username => @database_username, :password => @database_password, :database => @database_name)
        r = connection.query(query)

      end
        count_value = get_row_count(r)

      if count_value == 0
        return 0
      else
        r.each do |rr|
          return rr[0]
        end
      end
      connection.close()
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
      connection2 = Mysql2::Client.new(:host => @database_host, :username => @database_username, :password => @database_password, :database => @database_name)
      rows_effected = 0
      rows_effected = connection2.query(query)
      connection2.close
      return rows_effected
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
    if @connection == nil
      Mysql2::Client.new(:host => @database_host, :username => @database_username, :password => @database_password, :database => @database_name)
    end

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
    text = sanitize(text) unless !options[:sanitize]
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
        chapter_content = ""
        if chapter_content != nil
          if @use_new_mysql == 0
            chapter_content = @connection.escape_string(chapter_content)
          else

            chapter_content = @connection.escape(chapter_content)
          end

        end

        #ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
        # chapter_content = ic.iconv(chapter_content + ' ')[0..-2]
        ## update the source chapter record
        chapter_id = f.gsub(".txt", "")
        puts "reading chapter: #{chapter_id}"
        update_record_target("update #{@source_chapters_table} set storytext = \"#{chapter_content}\" where chapid = #{chapter_id}")
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
          puts "333 #{r.count}"

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