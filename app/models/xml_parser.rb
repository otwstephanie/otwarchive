# Parse stories from other websites and uploaded files, looking for metadata to harvest
# and put into the archive.
#
class StoryParser
  require 'timeout'
  require 'nokogiri'
  require 'mechanize'
  require 'open-uri'
  require 'nori'
  include Hashie
  include HtmlCleaner

  META_PATTERNS = {:title => 'Title',
                   :notes => 'Note',
                   :summary => 'Summary',
                   :freeform_string => "Tag",
                   :fandom_string => "Fandom",
                   :rating_string => "Rating",
                   :relationship_string => "Relationship|Pairing",
                   :revised_at => 'Date|Posted|Posted on|Posted at'
  }

  # Use this for raising custom error messages
  # (so that we can distinguish them from unexpected exceptions due to
  # faulty code)
  class Error < StandardError
  end

  # These attributes need to be moved from the work to the chapter
  # format: {:work_attribute_name => :chapter_attribute_name} (can be the same)
  CHAPTER_ATTRIBUTES_ONLY = {}

  # These attributes need to be copied from the work to the chapter
  CHAPTER_ATTRIBUTES_ALSO = {:revised_at => :published_at}


  # time out if we can't download fast enough
  STORY_DOWNLOAD_TIMEOUT = 60
  MAX_CHAPTER_COUNT = 200

  # To check for duplicate chapters, take a slice this long out of the story
  # (in characters)
  DUPLICATE_CHAPTER_LENGTH = 10000

  #Returns an external author from work mash
  def external_author_from_work_mash(iw_mash)
    e = ExternalAuthor.create(:email => iw_mash.author.email.to_s)
    parse_author_common(iw_mash.author.email, iw_mash.author.name)
  end

  #check collection ownership
  def check_if_own_collection(collection)
    owner = false
    User.current_user.pseuds.each do |p|
      if collection.owners.include?(p)
        owner = true
        return owner
      else
        owner = false
      end
    end
  end

  def find_or_create_collection(name)
    collection = Collection.find_or_initialize_by_name(name)
    if collection.new_record?
      collection.title = name
    end
    # add the user as an owner if not already one
    unless collection.owners.include?(User.current_user.default_pseud)
      p = collection.collection_participants.where(:pseud_id => User.current_user.default_pseud.id).first || collection.collection_participants.build(:pseud => User.current_user.default_pseud)
      p.participant_role = "Owner"
      collection.save
      p.save
    end
    collection.save
    return collection
  end


  def import_many_xml(options={})

    works = []
    failed_urls = []
    errors = []
    url = "nothing"

    begin
      hashed_works = parse_xml_to_hash(options[:xml_string], options)
    rescue
      errors << "The file provided was unable to be parsed. Please check the format and try again."
      return [works, failed_urls, errors]
    end

    mashed_works = Hashie::Mash.new(hashed_works)

    #loop through each work
    mashed_works.importworks.importwork.each do |import_work|
      #create the external author
      external_author_from_work_mash(import_work)

      begin
        work_mash = Hashie::Mash.new(Hash[*import_work.flatten])
        work = download_and_parse_story(work_mash, options)
        @collection = nil
        #if have work object and work save success
        if work && work.save
          work.chapters.each { |chapter| chapter.save }
          #Add to Collection if specified
          if import_work.collection
            #check that collection exists
            @collection = find_or_create_collection(import_work.collection.to_s)

            #check ownership
            if check_if_own_collection(@collection)
              work.add_to_collection(@collection)
            end
          end
          works << work
          #if work save failed
        else
          failed_urls << url
          errors << work.errors.values.join(", ")
          work.delete if work
        end

      rescue Timeout::Error
        failed_urls << url
        errors << "Import has timed out. This may be due to connectivity problems with the source site. Please try again in a few minutes, or check Known Issues to see if there are import problems with this site."
        work.delete if work
      rescue Error => exception
        failed_urls << url
        errors << "We couldn't successfully import that work, sorry: #{exception.message}"
        work.delete if work
      end
    end
    return [works, failed_urls, errors]
  end



  def parse_single_work(mash, options = {})
    location = mash.work.source_url
    work = nil
    check_for_previous_import(location)
    work = parse_story(mash, location, options)
    return work
  end

  #parse xml string to hash
  # @param [string] xml_string
  # @param [hash] options
  # @return [hash]
  def parse_xml_to_hash(xml_string, options = {})
    parser = Nori.new(:convert_tags_to => lambda { |tag| tag.downcase.to_sym })
    import_hash = parser.parse(xml_string)
    return import_hash
  end

  ### PARSING METHODS

  # Parses the text of a story, optionally from a given location.
  def parse_story(story, location, options = {})
    work_params = parse_common(story, location, options)

    # move any attributes from work to chapter if necessary
    return set_work_attributes(Work.new(work_params), story, options)

  end

  # parses and adds a new chapter to the end of the work
  def parse_chapter_of_work(work, chapter_content, location, options = {})
    tmp_work_params = parse_common(chapter_content, location, options)
    chapter = get_chapter_from_work_params(tmp_work_params)
    work.chapters << set_chapter_attributes(work, chapter, location, options)
    return work
  end

  #set chapter content, position, notes, summary, title
  #parse mash of chapter to chapter object
  # @param [Hashie::Mash] chapter_mash
  # @return [Chapter]
  def parse_chapter_mash_to_chapter(chapter_mash)
    my_chapter = Chapter.new
    my_chapter.content = clean_storytext(chapter_mash.content)
    my_chapter.position = chapter_mash.position

    if chapter_mash.notes
      my_chapter.notes = clean_storytext(chapter_mash.note)
    end

    if chapter_mash.summary
      my_chapter.summary = clean_storytext(chapter_mash.summary)
    end

    if chapter_mash.title
      my_chapter.title = chapter_mash.title
    else
      my_chapter.title = "Untitled Chapter"
    end

    return my_chapter
  end

  # parse mash chapters return work
  # @param [Work] work
  # @param [String] location
  # @param [Hashie::Mash] mash
  # @param [Hash] options
  # @return [Work]
  def parse_mash_chapters_into_story(work, location, mash, options = {})
    mash.work.chapter.each do |chapter|
      if chapter.position.to_i != 1
        new_chapter = parse_chapter_mash_to_chapter(chapter)
        work.chapters << set_chapter_attributes(work, new_chapter, location, options)
      end
    end
    return work
  end


  # our custom url finder checks for previously imported URL in almost any format it may have been presented
  def check_for_previous_import(location)
    if Work.find_by_url(location).present?
      raise Error, "A work has already been imported from #{location}."
    end
  end


  def set_chapter_attributes(work, chapter, location, options = {})
    chapter.position = work.chapters.length + 1
    chapter.posted = true # if options[:post_without_preview]
    return chapter
  end

  #return options hash with authors added from xml
  def xml_hash_to_mash_assign_authors(mash)
    options = {}
    if mash.author.class.to_s == "Array"
      options[:external_author_name] = mash.author[0].name
      options[:external_author_email] = mash.author[0].email
      options[:external_coauthor_name] = mash.authors.author[1].name
      options[:external_coauthor_email] = mash.authors.author[1].email
    else
      options[:external_author_name] = mash.author.name
      options[:external_author_email] = mash.author.email
    end
    return options
  end

  #set work authors
  # @param [Work] work
  # @param [String] location
  # @param [Hash] options
  def set_work_authors(work, location, options = {})
    # set authors for the works
    pseuds = []
    pseuds << User.current_user.default_pseud unless options[:do_not_set_current_author] || User.current_user.nil?
    pseuds << options[:archivist].default_pseud if options[:archivist]
    pseuds += options[:pseuds] if options[:pseuds]
    pseuds = pseuds.uniq
    raise Error, "A work must have at least one author specified" if pseuds.empty?
    pseuds.each do |pseud|
      work.pseuds << pseud unless work.pseuds.include?(pseud)
      work.chapters.each { |chapter| chapter.pseuds << pseud unless chapter.pseuds.include?(pseud) }
    end

    # handle importing works for others
    # build an external creatorship for each author
    if options[:importing_for_others]
      external_author_names = nil
      if options[:external_author_names]
        external_author_names = option[:external_author_names]
      else
        external_author_names = [parse_author(location, options[:external_author_name], options[:external_author_email])]
      end


      # convert to an array if not already one
      external_author_names = [external_author_names] if external_author_names.is_a?(ExternalAuthorName)
      if options[:external_coauthor_name] != nil
        external_author_names << parse_author(location, options[:external_coauthor_name], options[:external_coauthor_email])
      end
      external_author_names.each do |external_author_name|
        if external_author_name && external_author_name.external_author
          if external_author_name.external_author.do_not_import
            # we're not allowed to import works from this address
            raise Error, "Author #{external_author_name.name} at #{external_author_name.external_author.email} does not allow importing their work to this archive."
          end
          ec = work.external_creatorships.build(:external_author_name => external_author_name, :archivist => (options[:archivist] || User.current_user))
        end
      end
    end
    return work
  end

  # @param [Work] work
  # @param [String or Hashie::Mash] location
  # @param [Hash] options
  def set_work_attributes_from_mash(work, mash, options = {})
    raise Error, "Work could not be downloaded" if work.nil?

      url = String.try_convert(mash.work.source_url)
      work.imported_from_url = url
      if mash.work.chapter.class.to_s == "Array"
        work.expected_number_of_chapters = mash.work.chapter.length
        work = parse_mash_chapters_into_story(work, work.imported_from_url, mash, options)
      else
        work.expected_number_of_chapters = 1
      end

      work.restricted = options[:restricted] || options[:importing_for_others] || mash.work.restricted
      work.posted = true if options[:post_without_preview] || location.work.posted || options[:importing_for_others]

      #set options from mash
      options = options.merge(options_from_mash(mash))

      if options[:importing_for_others]
        options = options.merge(xml_hash_to_mash_assign_authors(mash))
      end



    # lock to registered users if specified or importing for others
    work.restricted = options[:restricted] || options[:importing_for_others] || false

    # set default values for required tags for any works that don't have them
    work.fandom_string = (options[:fandom].blank? ? ArchiveConfig.FANDOM_NO_TAG_NAME : options[:fandom]) if (options[:override_tags] || work.fandoms.empty?)
    work.rating_string = (options[:rating].blank? ? ArchiveConfig.RATING_DEFAULT_TAG_NAME : options[:rating]) if (options[:override_tags] || work.ratings.empty?)
    work.warning_strings = (options[:warning].blank? ? ArchiveConfig.WARNING_DEFAULT_TAG_NAME : options[:warning]) if (options[:override_tags] || work.warnings.empty?)
    work.category_string = options[:category] if !options[:category].blank? && (options[:override_tags] || work.categories.empty?)
    work.character_string = options[:character] if !options[:character].blank? && (options[:override_tags] || work.characters.empty?)
    work.relationship_string = options[:relationship] if !options[:relationship].blank? && (options[:override_tags] || work.relationships.empty?)
    work.freeform_string = options[:freeform] if !options[:freeform].blank? && (options[:override_tags] || work.freeforms.empty?)

    # set default value for title
    work.title = "Untitled Imported Work" if work.title.blank?

    #assign authors
    work = set_work_authors(work, work.imported_from_url, options)

    work.chapters.each do |chapter|
      if chapter.content.length > ArchiveConfig.CONTENT_MAX
        # TODO: eventually: insert a new chapter
        chapter.content.truncate(ArchiveConfig.CONTENT_MAX, :omission => "<strong>WARNING: import truncated automatically because chapter was too long! Please add a new chapter for remaining content.</strong>", :separator => "</p>")
      end

      chapter.posted = true
      # ack! causing the chapters to exist even if work doesn't get created!
      # chapter.save
    end
    return work
  end


  def parse_author_common(email, name)
    external_author = ExternalAuthor.find_or_create_by_email(email)
    unless name.blank?
      external_author_name = ExternalAuthorName.find(:first, :conditions => {:name => name, :external_author_id => external_author.id}) ||
          ExternalAuthorName.new(:name => name)
      external_author.external_author_names << external_author_name
      external_author.save
    end
    return external_author_name || external_author.default_name
  end

  def get_chapter_from_work_params(work_params)
    @chapter = Chapter.new(work_params[:chapter_attributes])
    # don't override specific chapter params (eg title) with work params
    chapter_params = work_params.delete_if { |name, param| !@chapter.attribute_names.include?(name.to_s) || !@chapter.send(name.to_s).blank? }
    @chapter.update_attributes(chapter_params)
    return @chapter
  end


  # This is the heavy lifter, invoked by all the story and chapter parsers.
  # It takes a single string containing the raw contents of a story, parses it with
  # Nokogiri into the @doc object, and then and calls a subparser.
  #
  # If the story source can be identified as one of the sources we know how to parse in some custom/
  # special way, parse_common calls the customized parse_story_from_[source] method.
  # Otherwise, it falls back to parse_story_from_unknown.
  #
  # This produces a hash equivalent to the params hash that is normally created by the standard work
  # upload form.
  #
  # parse_common then calls sanitize_params (which would also be called on the standard work upload
  # form results) and returns the final sanitized hash.
  #
  def parse_common(story, location = nil, options={})
    work_params = {:title => "UPLOADED WORK", :chapter_attributes => {:content => ""}}
    encoding = options[:encoding]
      params = parse_story_from_mash(story)
      work_params.merge!(params)


    return shift_chapter_attributes(sanitize_params(work_params))
  end


  # @param [Hashie::Mash] mash
  def parse_story_from_mash(mash)
    m = mash
    work_params = {:chapter_attributes => {}}
    if m.work.chapter.class.to_s == "Array"
      work_params[:chapter_attributes][:content] = m.work.chapter[0].content
      work_params[:chapter_attributes][:title] = m.work.chapter[0].title
    else
      work_params[:chapter_attributes][:content] = m.work.chapter.content.to_s
      work_params[:chapter_attributes][:title] = m.work.chapter.title.to_s
    end

    work_params[:title] = m.work.title
    work_params[:summary] = clean_storytext(m.work.summary)

    return work_params
  end

  def fix_tag_string(s)
    s.gsub /"/, ''
  end

  def options_from_mash(mash, options={})
    #stings to hold comma delimited values
    fandoms = nil
    characters = nil
    freeforms = nil
    warnings = nil
    relationships = nil
    categories = nil

    #famdoms to comma string
    if mash.work.tags.fandom.class.to_s == "Array"
      fandoms = mash.work.tags.fandom.map(&:inspect).join(', ')
    else
      fandoms = mash.work.tags.fandom
    end

    #freeforms to comma string
    if mash.work.tags.freeform.class.to_s == "Array"
      freeforms = mash.work.tags.freeform.map(&:inspect).join(', ')
    else
      freeforms = mash.work.tags.freeform
    end

    #characters to comma string
    if mash.work.tags.character.class.to_s == "Array"
      characters = mash.work.tags.character.map(&:inspect).join(', ')
    else
      characters = mash.work.tags.character
    end

    #warnings to comma string
    if mash.work.tags.warning.class.to_s == "Array"
      warnings = mash.work.tags.warning.map(&:inspect).join(', ')
    else
      warnings = mash.work.tags.warning
    end

    #relationships to comma string
    if mash.work.tags.relationship.class.to_s == "Array"
      relationships = mash.work.tags.relationship.map(&:inspect).join(', ')
    else
      relationships = mash.work.tags.relationship
    end

    #categories to comma string
    if mash.work.tags.category.class.to_s == "Array"
      categories = mash.work.tags.category.map(&:inspect).join(', ')
    else
      categories = mash.work.tags.category
    end

    #ratings to string
    rating = mash.work.tags.rating


    if rating
      options[:rating] = convert_rating(rating)
    else
      options[:rating] = ArchiveConfig.RATING_DEFAULT_TAG
    end

    if fandoms
      options[:fandom] = fix_tag_string(clean_tags(fandoms))
    else
      options[:fandom] = ArchiveConfig.FANDOM_NO_TAG_NAME
    end


    if categories
      options[:category] = fix_tag_string(clean_tags(categories))
    else
      categories = "Gen"
    end

    if warnings
      options[:warning] = fix_tag_string(clean_tags(warnings))
    else
      options[:warning] = ArchiveConfig.WARNING_DEFAULT_TAG_NAME
    end

    if characters
      options[:character] = fix_tag_string(clean_tags(characters))
    end

    if relationships
      options[:relationship] = fix_tag_string(clean_tags(relationships))
    end

    if freeforms
      options[:freeform] = fix_tag_string(clean_tags(freeforms))
    end

    #work_params[:notes] = clean_storytext(mash.work.note)
    #work_params[:revised_at] = mash.work.date_updated
    # work_params[:completed] = mash.work.completed


    return options
  end


  # Move and/or copy any meta attributes that need to be on the chapter rather
  # than on the work itself
  def shift_chapter_attributes(work_params)
    CHAPTER_ATTRIBUTES_ONLY.each_pair do |work_attrib, chapter_attrib|
      if work_params[work_attrib] && !work_params[:chapter_attributes][chapter_attrib]
        work_params[:chapter_attributes][chapter_attrib] = work_params[work_attrib]
        work_params.delete(work_attrib)
      end
    end

    # copy any attributes from work to chapter as necessary
    CHAPTER_ATTRIBUTES_ALSO.each_pair do |work_attrib, chapter_attrib|
      if work_params[work_attrib] && !work_params[:chapter_attributes][chapter_attrib]
        work_params[:chapter_attributes][chapter_attrib] = work_params[work_attrib]
      end
    end

    work_params
  end


  def get_last_modified(location)
    Timeout::timeout(STORY_DOWNLOAD_TIMEOUT) {
      resp = open(location)
      resp.last_modified
    }
  end


  def clean_close_html_tags(value)
    # if there are any closing html tags at the start of the value let's ditch them
    value.gsub(/^(\s*<\/[^>]+>)+/, '')
  end

  # We clean the text as if it had been submitted as the content of a chapter
  def clean_storytext(storytext)
    storytext = storytext.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "") unless storytext.encoding.name == "UTF-8"
    return sanitize_value("content", storytext)
  end

  # works conservatively -- doesn't split on
  # spaces and truncates instead.
  def clean_tags(tags)
    tags = Sanitize.clean(tags) # no html allowed in tags
    if tags.match(/,/)
      tagslist = tags.split(/,/)
    else
      tagslist = [tags]
    end
    newlist = []
    tagslist.each do |tag|
      tag.gsub!(/[\*\<\>]/, '')
      tag = truncate_on_word_boundary(tag, ArchiveConfig.TAG_MAX)
      newlist << tag unless tag.blank?
    end
    return newlist.join(ArchiveConfig.DELIMITER_FOR_OUTPUT)
  end

  def truncate_on_word_boundary(text, max_length)
    return if text.blank?
    words = text.split()
    truncated = words.first
    if words.length > 1
      words[1..words.length].each do |word|
        truncated += " " + word if truncated.length + word.length + 1 <= max_length
      end
    end
    truncated[0..max_length-1]
  end

  # convert space-separated tags to comma-separated
  def clean_and_split_tags(tags)
    if !tags.match(/,/) && tags.match(/\s/)
      tags = tags.split(/\s+/).join(',')
    end
    return clean_tags(tags)
  end

  # Convert the common ratings into whatever ratings we're
  # using on this archive.
  def convert_rating(rating)
    rating = rating.downcase
    if rating.match(/^(nc-?1[78]|x|ma|explicit)/)
      ArchiveConfig.RATING_EXPLICIT_TAG_NAME
    elsif rating.match(/^(r|m|mature)/)
      ArchiveConfig.RATING_MATURE_TAG_NAME
    elsif rating.match(/^(pg-?1[35]|t|teen)/)
      ArchiveConfig.RATING_TEEN_TAG_NAME
    elsif rating.match(/^(pg|g|k+|k|general audiences)/)
      ArchiveConfig.RATING_GENERAL_TAG_NAME
    else
      ArchiveConfig.RATING_DEFAULT_TAG_NAME
    end
  end

  def convert_rating_string(rating)
    return convert_rating(rating)
  end

  def convert_revised_at(date_string)
    begin
      date = nil
      if date_string.match(/^(\d+)$/)
        # probably seconds since the epoch
        date = Time.at($1.to_i)
      end
      date ||= Date.parse(date_string)
      return '' if date > Date.today
      return date
    rescue ArgumentError, TypeError
      return ''
    end
  end

  # tries to find appropriate existing collections and converts them to comma-separated collection names only
  def get_collection_names(collection_string)
    cnames = ""
    collection_string.split(',').map { |cn| cn.squish }.each do |collection_name|
      collection = Collection.find_by_name(collection_name) || Collection.find_by_title(collection_name)
      if collection
        cnames += ", " unless cnames.blank?
        cnames += collection.name
      end
    end
    cnames
  end

end
