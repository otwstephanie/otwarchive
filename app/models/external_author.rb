class ExternalAuthor < ActiveRecord::Base

  # send :include, Activation # eventually we will let users create new identities

  EMAIL_LENGTH_MIN = 3
  EMAIL_LENGTH_MAX = 300

  belongs_to :user

  has_many :external_author_names, :dependent => :destroy
  accepts_nested_attributes_for :external_author_names, :allow_destroy => true
  validates_associated :external_author_names

  has_many :external_creatorships, :through => :external_author_names
  has_many :works, :through => :external_creatorships, :source => :creation, :source_type => 'Work', :uniq => true

  has_one :invitation

  validates_uniqueness_of :email, :case_sensitive => false, :allow_blank => true,
    :message => ts('There is already an external author with that email.')

  validates :email, :email_veracity => true
  
  def self.claimed
    where(:is_claimed => true)
  end
  
  def self.unclaimed
    where(:is_claimed => false)
  end

  after_create :create_default_name

  def external_work_creatorships
    external_creatorships.where("external_creatorships.creation_type = 'Work'")
  end

  def create_default_name
    @default_name = self.external_author_names.build
    @default_name.name = self.email.to_s
    self.save
  end

  def default_name
    self.external_author_names.select {|external_name| external_name.name == self.email.to_s }.first
  end

  def names
    self.external_author_names
  end

  def claimed?
    is_claimed
  end

  def claim!(claiming_user)
    raise "There is no user claiming this external author." unless claiming_user
    raise "This external author is already claimed by another user" if claimed? && self.user != claiming_user

    claimed_works = []
    external_author_names.each do |external_author_name|
      external_author_name.external_work_creatorships.each do |external_creatorship|
        work = external_creatorship.creation
        # if previously claimed, don't do it again

        pseud_to_add = claiming_user.pseuds.select {|pseud| pseud.name == external_author_name.name}.first || claiming_user.default_pseud

        unless work.users.include?(claiming_user)
          # remove archivist as owner if still on the work -- might not be if another coauthor already claimed, add user as owner
          archivist = external_creatorship.archivist
          work.change_ownership(archivist, claiming_user, pseud_to_add)

          claimed_works << work.id
        end
        current_creatorship = Creatorship.find_by_creation_id_and_creation_type(external_creatorship.creation.id,"Work")
        if current_creatorship.nil?
          new_creatorship = Creatorship.new
          new_creatorship.pseud = pseud_to_add
          new_creatorship.creation = external_creatorship.creation
          new_creatorship.save!
        end
        external_creatorship.delete
      end
    end

    self.user = claiming_user
    self.is_claimed = true
    save
    notify_user_of_claim(claimed_works)
  end

  def unclaim!
    return false unless self.is_claimed

    self.external_work_creatorships.each do |external_creatorship|
      # remove user, add archivist back
      archivist = external_creatorship.archivist
      work = external_creatorship.creation
      work.change_ownership(user, archivist)
    end

    self.user = nil
    self.is_claimed = false
    save
  end

  def orphan(remove_pseud)
    external_author_names.each do |external_author_name|
      external_author_name.external_work_creatorships.each do |external_creatorship|
        # remove archivist as owner, convert to the pseud
        archivist = external_creatorship.archivist
        work = external_creatorship.creation
        archivist_pseud = work.pseuds.select {|pseud| archivist.pseuds.include?(pseud)}.first
        orphan_pseud = remove_pseud ? User.orphan_account.default_pseud : User.orphan_account.pseuds.find_or_create_by_name(external_author_name.name)
        work.change_ownership(archivist, User.orphan_account, orphan_pseud)
      end
    end
  end

  def delete_works
    self.external_work_creatorships.each do |external_creatorship|
      work = external_creatorship.creation
      work.chapters.each do |c|
        c.creatorship.delete
      end
end

      work.destroy
    end
  end

  def block_import
    self.do_not_import = true
    save
  end

  def notify_user_of_claim(claimed_work_ids)
    # send announcement to user of the stories they have been given
    UserMailer.claim_notification(self.id, claimed_work_ids).deliver
  end

  def find_or_invite(archivist = nil)
    if self.email
      matching_user = User.find_by_email(self.email)
      if matching_user
        self.claim!(matching_user)
      else
        # invite person at the email address unless they don't want invites
        unless self.do_not_email
          @invitation = Invitation.new(:invitee_email => self.email, :external_author => self, :creator => User.current_user)
          @invitation.save
        end
      end
    end
    # eventually we may want to try finding authors by pseud?
  end

end
