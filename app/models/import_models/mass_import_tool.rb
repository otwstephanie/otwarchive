# encoding=utf-8
# Mass Import Tool
# Questions? Ask Stephanie =)
class MassImportTool
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::TagHelper #tag_options needed by auto_link
  require 'mysql2'
  require 'mysql'

  def initialize(import_id)
    #Import Class Version Number
    @version = 1

    #Archive Import Object
    @ai = ArchiveImport.find(import_id)
    #Archive Import Settings
    @ais = ArchiveImportSettings.find_all_by_archive_import_id(import_id)

    @connection = nil
    if @ais.use_new_mysql == 0 then
      @connection = Mysql.new(@ais.source_database_host, @ais.source_database_username, @ais.source_database_password, @ais.source_database_name)
    else
      @connection = Mysql2::Client.new(:host => @ais.source_database_host, :username => @ais.source_database_username, :password => @ais.source_database_password, :database => @source_database_name)
    end

    #Default Language for imported works
    @default_language = Language.find_by_short("en")

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
  end

  ##################################################################################################
  # Main Worker Sub
  def import_data
    puts "1) Setting Import Values"
    self.set_import_strings(@ais.source_archive_type)
    self.create_archivist_and_collection
    self.create_import_record
    @import_files_path = "#{Rails.root.to_s}/imports/#{@ai.id}"

    puts "2) Running File Operations"
    run_file_operations

    puts "3) Updating Tags"
    source_archive_tag_list = Array.new()

    ## create list of all tags used in source
    source_archive_tag_list = get_tag_list(source_archive_tag_list)

    ## check for tag existance on target archive
    source_archive_tag_list = self.fill_tag_list(source_archive_tag_list)

    puts "4) Importing Stories"
    ## pull source stories from database to array of rows
    r = @connection.query("SELECT * FROM #{@source_stories_table} ;")

    i = 0
    r.each do |row|
      puts " Importing Story ID#{row[0]}"
      #Check to ensure work hasnt already been imported for this import run / archive
      #ignored if rerun_import  = 1
      if @ais.rerun_import == 0
        temp_work_import = WorkImport.find_by_source_archive_id_and_source_work_id(@ai.id, row[0])
        # if puts msg isnt important could use next if as done below when checking for presence of chapters
        if temp_work_import.empty? || temp_work_import == nil
          puts "##### Story Previously Imported For This Archive #####"
          next
        end
      end

      new_import_work = ImportWork.new()
      import_user = ImportUser.new()

      ## Create Taglisit for this story
      new_import_work.tag_list =  Array.new()

      ## assign data to import work object
      new_import_work = ImportWork.new
      new_import_work = assign_row_import_work(new_import_work, row)
      #new_import_work.tag_list
      #todo looks like something is missing here

      ## goto next if no chapters
      num_source_chapters = 0
      num_source_chapters = get_single_value_target("Select chapid  from #{@source_chapters_table} where sid = #{new_import_work.old_work_id} limit 1")
      next if num_source_chapters == 0

      ## see if user / author exists for this import already
      user_import = UserImport.find_by_source_user_id_and_source_archive(old_id,@ai.id)

      if user_import != nil
        new_import_work.new_user_id = user_import.id
      end
      ## get import user object from source database
      import_user = self.get_import_user_object_from_source(new_import_work.old_user_id)
      if user_import == nil
        new_import_work.new_user_id = 0
        puts "user didnt exist in this import session"
        ## see if user account exists in main archive by checking email,
        temp_user_object = User.find_by_email(import_user.email)

        if temp_user_object == nil
          ## if not exist , add new user with user object, passing old author object
          import_user = ImportUser.new
          import_user = self.add_user(import_user)

          ## pass values to new story object
          new_import_work.penname = import_user.penname
          new_import_work.new_user_id = import_user.new_user_id

          ## get newly created pseud id
          new_pseud_id = get_default_pseud_id(new_import_work.new_user_id)

          ## set the penname on newly created pseud to proper value
          update_record_target("update pseuds set name = '#{new_import_work.penname}' where id = #{new_pseud_id}")

          #create_user_import(import_user.new_user_id, new_pseud_id, ns.old_user_id, @archive_import_id)
          new_import_work.new_pseud_id = new_pseud_id
        else
          ## user exists, but is being imported
          ## insert the mapping value
          puts "Debug: User existed in Target Archive"
          new_import_work.penname = import_user.penname

          ## check to see if penname exists as pseud for existing user
          temp_pseud_object = Pseud.find_by_user_id_and_name(temp_user_object.id,new_import_work.penname)
          #temp_pseud_id = get_pseud_id_for_penname(temp_author_object.id, ns.penname)

          if temp_pseud_object == nil

            ## add pseud if not exist
            temp_pseud_object = create_new_pseud(temp_user_object.id, import_user.penname, true, "Imported")
            new_import_work.new_pseud_id = temp_pseud_object.id

            ## create USER IMPORT
            create_user_import(temp_user_object.id, temp_pseud_object.id, new_import_work.old_user_id, @ai.id)
            # 'temp_pseud_id = get_pseud_id_for_penname(ns.new_user_id,ns.penname)
            #todo edit out
            update_record_target("update user_imports set pseud_id = #{temp_pseud_object.id} where user_id = #{new_import_work.new_user_id} and source_archive_id = #{@ai.id}")
            new_import_work.new_user_id = temp_pseud_object.id
            import_user.pseud_id = temp_pseud_object.id
          end
        end
      else
        new_import_work.penname = import_user.penname
        #TODO  CONVERT TO AR , CAN BE GOTTEN BEFORE POSSIBLY?
        import_user.pseud_id = get_pseud_id_for_penname(new_import_work.new_user_id, new_import_work.penname)
        puts "#{import_user.pseud_id} this is the matching pseud id"
        new_import_work.new_pseud_id = import_user.pseud_id
      end
      ## insert work object
      new_work = prepare_work(new_import_work)
      # todo investigate why i was checking length < 5 , steph
      next if new_work.chapters[0].content.length < 5
      new_work.save!
      add_chapters(new_work, new_import_work.old_work_id, false)

      ## add all chapters to work
      new_work.expected_number_of_chapters = new_work.chapters.count
      new_work.save

      puts "Taglist count = #{new_import_work.tag_list.count}"
      new_import_work.tag_list.each do |t|
        add_work_taggings(new_work.id, t)
      end

      ## save first chapter reviews since cand do it in addchapters like rest
      old_first_chapter_id = get_single_value_target("Select chapid from  #{@source_chapters_table} where sid = #{new_import_work.old_work_id} order by inorder asc Limit 1")
      import_chapter_reviews(old_first_chapter_id, new_work.chapters.first.id)

      create_new_work_import(new_work, new_import_work, @ai.id)
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
      #Tagging will be of work type so go ahead and set it so
      my_tagging.taggable_type="Work"
      temp_tag = Tag.find_by_name(new_tag.tag)
      unless temp_tag.name == nil
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
          if @ais.categories_as_tags == 1
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


  ####Reserved####
  ##gets the collections that the work is supposed to be in based on old cat id's
  ##note: until notice, this function will not be used.
  def get_work_collections(collection_string)
    temp_string = collection_string
    temp_array = Array.new
    collection_string = temp_string.split(",")
    collection_string.each do |c|
      new_collection_id = get_single_value_target("Select new_id from collection_imports where source_archive_id = #{@ai.id} AND old_id = #{c} ")
      temp_collection = Collection.find(new_collection_id)
      temp_array.push(temp_collection)
    end
    #collection_string = temp_array
    return temp_array
  end


  #Add User, takes ImportUser
  # @param [ImportUser]  import_user   ImportUser object to add
  def add_user(import_user)
    begin
      email_array = import_user.email.split("@")
      login_temp = email_array[0] #take first part of email
      login_temp = login_temp.tr(".", "") # remove any dots
      login_temp = "i#{@ai.id}#{login_temp}" #prepend archive id
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
    new_work.fandom_string = @ai.import_fandom

    #todo finish rating code assignment, steph, 9-15-2013
    new_work.rating_string = "Not Rated"
    new_work.warning_strings = "None"
    puts "old work id = #{import_work.old_work_id}"
    #todo - see if there is a better way other then setting the value here, may be redundant, steph 9-15-2013
    new_work.imported_from_url = "#{@id.id}~~#{import_work.old_work_id}"

    new_work.language = @default_language
    new_work = add_chapters(new_work, import_work.old_work_id, true)

    ##assign to main import collection
    new_work.collections << Collection.find(@new_collection_id)

    return new_work
  end

  #Create new work import, takes Work , ImportWork
  # @param [work] new_work
  # @param [importwork] ns
  # @param [integer] archive_import_id
  def create_new_work_import(new_work, ns, archive_import_id)
    begin
      new_wi = WorkImport.new
      new_wi.work_id = new_work.id
      new_wi.pseud_id = ns.new_user_id
      new_wi.source_archive_id = archive_import_id
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
    u = User.find_or_initialize_by_login(@ais.archivist_login)
    if u.new_record?
      u.password = @ais.archivist_password
      u.email = @ais.archivist_email
      u.age_over_13 = "1"
      u.terms_of_service = "1"
      #below line might not be needed
      u.password_confirmation = @ais.archivist_password
    end
    unless u.is_archivist?
      u.roles << Role.find_by_name("archivist")
      u.save
    end
    @ai.archivist_user_id = u.id
    if @ais.check_archivist_activated == 1
      unless u.activated_at
        u.activate
      end
    end
    c = Collection.find_or_initialize_by_name(@new_collection_name)
    if c.new_record?
      c.description = @ais.new_collection_description
      c.title = @ais.new_collection_title
    else
      #todo consider setting values for consistance back from lookup above steph 9-27
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
    @ai.associated_collection_id = c.id

    puts "Archivist #{u.login} set up and owns collection #{c.name}."
  end

  #Function to return row count due to multi adapter
  def get_row_count(row_set)
    count_value = nil
    if @ais.use_new_mysql == 0
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
  def create_import_record(import_name,source_archive_type,source_base_url,new_collection_id,new_url,archivist_user_id)
    #changed to take all values as params 9-27 , probably isnt even needed at all since should be idealy called before class init
    # done- 9-18-2013 - update to use ar new method and save since is proper ar class now, make sure it returns new value after save - steph 9-9-13
    #update_record_target("insert into archive_imports (name,archive_type_id,old_base_url,associated_collection_id,new_user_notice_id,existing_user_notice_id,existing_user_email_id,new_user_email_id,new_url,archivist_user_id)  values ('#{@import_name}',#{@source_archive_type},'#{
    #@source_base_url}',#{@new_collection_id},#{@new_user_notice_id},#{@existing_user_notice_id},#{@new_user_email_id},#{@existing_user_email_id},'#{@new_url}',#{@archivist_user_id})")
    begin
      archive_import = ArchiveImport.new
      archive_import.name = import_name
      archive_import.archive_type_id = source_archive_type
      archive_import.old_base_url = source_base_url
      archive_import.associated_collection_id = new_collection_id
      archive_import.new_url = new_url
      archive_import.archivist_user_id = archivist_user_id
      archive_import.save!
      puts "record created"
      new_record = ArchiveImport.find_by_old_base_url(source_base_url)

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
  def create_new_pseud(user_id, name, default, description)
    begin
      new_pseud = Pseud.new
      new_pseud.user_id = user_id
      new_pseud.name = name
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
        @source_chapters_table = "#{@source_temp_table_prefix}#{@source_table_prefix}chapters"
        @source_reviews_table = "#{@source_temp_table_prefix}#{@source_table_prefix}reviews"
        @source_stories_table = "#{@source_temp_table_prefix}#{@source_table_prefix}stories"
        @source_categories_table = "#{@source_temp_table_prefix}#{@source_table_prefix}categories"
        @source_users_table = "#{@source_temp_table_prefix}#{@source_table_prefix}authors"
        @source_characters_table = "#{@source_temp_table_prefix}#{@source_table_prefix}characters"
        @source_warnings_table = "#{@source_temp_table_prefix}#{@source_table_prefix}warnings"
        @source_generes_table = "#{@source_temp_table_prefix}#{@source_table_prefix}generes"
        @source_author_query = " "

      when 2 ## efiction2
        @source_chapters_table = "#{@source_temp_table_prefix}#{@source_table_prefix}chapters"
        @source_reviews_table = "#{@source_temp_table_prefix}#{@source_table_prefix}reviews"
        @source_stories_table = "#{@source_temp_table_prefix}#{@source_table_prefix}stories"
        @source_characters_table = "#{@source_temp_table_prefix}#{@source_table_prefix}characters"
        @source_warnings_table = "#{@source_temp_table_prefix}#{@source_table_prefix}warnings"
        @source_generes_table = "#{@source_temp_table_prefix}#{@source_table_prefix}generes"
        @source_users_table = "#{@source_temp_table_prefix}#{@source_table_prefix}authors"
        @source_author_query = "Select realname, penname, email, bio, date, pass, website, aol, msn, yahoo, icq, ageconsent from  #{@source_users_table} where uid ="

      when 3 ## efiction3
        @source_chapters_table = "#{@source_temp_table_prefix}#{@source_table_prefix}chapters"
        @source_reviews_table = "#{@source_temp_table_prefix}#{@source_table_prefix}reviews"
        @source_challenges_table = "#{@source_temp_table_prefix}#{@source_table_prefix}challenges"
        @source_stories_table = "#{@source_temp_table_prefix}#{@source_table_prefix}stories"
        @source_categories_table = "#{@source_temp_table_prefix}#{@source_table_prefix}categories"
        @source_characters_table = "#{@source_temp_table_prefix}#{@source_table_prefix}characters"
        @source_series_table = "#{@source_temp_table_prefix}#{@source_table_prefix}series"
        @source_inseries_table = "#{@source_temp_table_prefix}#{@source_table_prefix}inseries"
        @source_ratings_table = "#{@source_temp_table_prefix}#{@source_table_prefix}ratings"
        @source_classes_table = "#{@source_temp_table_prefix}#{@source_table_prefix}classes"
        @source_class_types_table = "#{@source_temp_table_prefix}#{@source_table_prefix}class_types"
        @source_users_table = "#{@source_temp_table_prefix}#{@source_table_prefix}authors"
        @source_author_query = "Select realname, penname, email, bio, date, password from #{@source_users_table} where uid ="

      when 4 ## storyline
        @source_chapters_table = "#{@source_temp_table_prefix}#{@source_table_prefix}chapters"
        @source_reviews_table = "#{@source_temp_table_prefix}#{@source_table_prefix}reviews"
        @source_stories_table = "#{@source_temp_table_prefix}#{@source_table_prefix}stories"
        @source_users_table = "#{@source_temp_table_prefix}#{@source_table_prefix}users"
        @source_categories_table = "#{@source_temp_table_prefix}#{@source_table_prefix}category"
        @source_subcategories_table = "#{@source_temp_table_prefix}#{@source_table_prefix}subcategory"
        @source_hitcount_table = "#{@source_temp_table_prefix}#{@source_table_prefix}rating"
        @source_ratings_table = nil #None
        @source_author_query = "SELECT urealname, upenname, uemail, ubio, ustart, upass, uurl, uaol, umsn, uicq from #{@source_users_table} where uid ="

      when 5 ## otwarchive
        @source_users_table = "#{@source_temp_table_prefix}#{@source_table_prefix}users"
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

  # Updated to be able to use multiple gems
  #query and return a single value from database
  # @param [string] query
  # @return [string or integer] if no result found returns 0
  def get_single_value_target(query)
    begin
      r = nil
      connection = nil
      count_value = nil

      if @ais.use_new_mysql == 0
        connection = Mysql.new(@ais.source_database_host, @ais.source_database_username, @ais.source_database_password, @ais.source_database_name)
        r = connection.query(query)

      else
        connection = Mysql2::Client.new(:host => @ais.source_database_host, :username => @ais.source_database_username, :password => @ais.source_database_password, :database => @ais.source_database_name)
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
      connection2 = Mysql2::Client.new(:host => @ais.source_database_host, :username => @ais.source_database_username, :password => @ais.source_database_password, :database => @ais.source_database_name)
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
      a.source_archive_id = @ai.id
      a.penname = row[1]
      a.email = row[2]
      a.bio = row[3]
      a.joindate = row[4]
      a.password = row[5]
      if @ais.source_archive_type == 2 || @ais.source_archive_type == 4
        a.website = row[6]
        a.aol = row[7]
        a.msn = row[8]
        a.icq = row[9]
        a.bio = self.build_bio(a).bio
        a.yahoo = ""
        if @ais.source_archive_type == 2
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

  #assign row data to import_Work object
  # @param [import_work] new_work_import
  # @param [mysql_row] row
  def assign_row_import_work(new_work_import, row)
    new_work_import.source_archive_id = @ai.id

    case @source_archive_type
      when 4 ## storyline
        new_work_import.old_work_id = row[0]
        #puts ns.old_work_id
        new_work_import.title = row[1]
        #debug info
        #puts ns.title
        new_work_import.summary = row[2]
        new_work_import.old_user_id = row[3]
        new_work_import.rating_integer = row[4]
        #Assign Tags
        rating_tag = ImportTag.new()
        rating_tag.tag_type = "Freeform"
        rating_tag.new_id = new_work_import.rating_integer
        new_work_import.tag_list.push(rating_tag)
        new_work_import.published = row[5]
        cattag = ImportTag.new()
        subcattag = ImportTag.new()
        subcattag.tag_type = "Freeform"
        cattag.tag_type = "Freeform"
        cattag.new_id = row[6]
        subcattag.new_id =row[11]
        new_work_import.tag_list.push(cattag)
        new_work_import.tag_list.push(subcattag)
        new_work_import.updated = row[9]
        new_work_import.completed = row[12]
        new_work_import.hits = row[10]

      when 3 ## efiction 3
        new_work_import.old_work_id = row[0]
        new_work_import.title = row[1]
        new_work_import.summary = row[2]
        new_work_import.old_user_id = row[10]
        new_work_import.classes = row[5]
        new_work_import.categories = row[4]
        new_work_import.characters = row[6]
        new_work_import.rating_integer = row[7]
        rating_tag = ImportTag.new()
        rating_tag.tag_type = "Freeform"
        rating_tag.new_id = new_work_import.rating_integer
        new_work_import.tag_list.push(rating_tag)
        new_work_import.published = row[8]
        new_work_import.updated = row[9]
        new_work_import.completed = row[14]
        new_work_import.hits = row[18]
        if !@ais.source_warning_class_id == nil
          #todo why did you have this here? steph 9-9-13
        end
        ## fill taglist with import tags to be added
        new_work_import.tag_list = get_source_work_tags(new_work_import.tag_list, new_work_import.classes, "classes")
        puts "Getting class tags: tag count = #{new_work_import.tag_list.count}"
        new_work_import.tag_list = get_source_work_tags(new_work_import.tag_list, new_work_import.characters, "characters")
        if @ais.categories_as_tags == 1
          new_work_import.tag_list = get_source_work_tags(new_work_import.tag_list, new_work_import.categories, "categories")
          puts "Getting category tags: tag count = #{new_work_import.tag_list.count}"
        end
      else
        puts "Error: (assign_row_import_work): Invalid source archive type, or type not yet Implemented."
    end
    return new_work_import
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
    `mv /tmp/#{@ais.sql_filename} #{@import_files_path}`
    `unzip #{@import_files_path}/#{@ais.sql_filename} -d #{@import_files_path}`
    transform_source_sql()
    load_source_db()
    begin
      if @archive_has_chapter_files
        `mv /tmp/#{@ais.archive_chapters_filename} #{@import_files_path}`
        `unzip #{@import_files_path}/#{@ais.archive_chapters_filename} -d #{@import_files_path}`
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
          if @ais.use_new_mysql == 0
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
    sql_file = read_file_to_string("#{@import_files_path}/#{@ais.sql_filename}")
    ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
    valid_string = ic.iconv(sql_file + ' ')[0..-2]
    sql_file = valid_string
    sql_file = sql_file.gsub("TYPE=MyISAM", "")
    sql_file = sql_file.gsub(@ais.source_table_prefix, "#{@ais.source_temp_table_prefix}#{@ais.source_table_prefix}")
    save_string_to_file(sql_file, "#{@import_files_path}/data_clean.sql")
  end

  #load cleaned source db file into mysql
  def load_source_db
    `mysql -u #{@ais.source_database_username} -p#{@ais.source_database_password} #{@ais.source_database_name} < #{@import_files_path}/data_clean.sql`
  end

end