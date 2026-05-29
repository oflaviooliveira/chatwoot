# The AgentBuilder class is responsible for creating a new agent.
# It initializes with necessary attributes and provides a perform method
# to create a user and account user in a transaction.
class AgentBuilder
  DEFAULT_INBOX_NAME = 'Gquicks HUB - Atendimento Web'.freeze

  # Initializes an AgentBuilder with necessary attributes.
  # @param email [String] the email of the user.
  # @param name [String] the name of the user.
  # @param role [String] the role of the user, defaults to 'agent' if not provided.
  # @param inviter [User] the user who is inviting the agent (Current.user in most cases).
  # @param availability [String] the availability status of the user, defaults to 'offline' if not provided.
  # @param auto_offline [Boolean] the auto offline status of the user.
  pattr_initialize [:email, { name: '' }, :inviter, :account, { role: :agent }, { availability: :offline }, { auto_offline: false }]

  # Creates a user and account user in a transaction.
  # @return [User] the created user.
  def perform
    ActiveRecord::Base.transaction do
      @user = find_or_create_user
      @account_user = create_account_user
      add_to_default_inbox
    end
    @user
  end

  private

  # Finds a user by email or creates a new one with a temporary password.
  # @return [User] the found or created user.
  def find_or_create_user
    user = User.from_email(email)
    return user if user

    @name = email.split('@').first if @name.blank?
    temp_password = "1!aA#{SecureRandom.alphanumeric(12)}"
    User.create!(email: email, name: @name, password: temp_password, password_confirmation: temp_password)
  end

  # Checks if the user needs confirmation.
  # @return [Boolean] true if the user is persisted and not confirmed, false otherwise.
  def user_needs_confirmation?
    @user.persisted? && !@user.confirmed?
  end

  # Creates an account user linking the user to the current account.
  def create_account_user
    AccountUser.create!({
      account_id: account.id,
      user_id: @user.id,
      inviter_id: inviter.id
    }.merge({
      role: role,
      availability: availability,
      auto_offline: auto_offline
    }.compact))
  end

  def add_to_default_inbox
    return if @account_user.administrator?

    default_inbox = account.inboxes.find_by(name: DEFAULT_INBOX_NAME)
    return unless default_inbox
    return if default_inbox.inbox_members.exists?(user_id: @user.id)

    default_inbox.add_members([@user.id])
  end
end

AgentBuilder.prepend_mod_with('AgentBuilder')
