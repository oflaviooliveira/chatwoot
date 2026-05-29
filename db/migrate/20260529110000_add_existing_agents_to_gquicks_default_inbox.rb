class AddExistingAgentsToGquicksDefaultInbox < ActiveRecord::Migration[7.1]
  DEFAULT_INBOX_NAME = 'Gquicks HUB - Atendimento Web'.freeze

  class MigrationAccount < ActiveRecord::Base
    self.table_name = 'accounts'
    has_many :inboxes,
             class_name: 'AddExistingAgentsToGquicksDefaultInbox::MigrationInbox',
             foreign_key: :account_id
    has_many :account_users,
             class_name: 'AddExistingAgentsToGquicksDefaultInbox::MigrationAccountUser',
             foreign_key: :account_id
  end

  class MigrationAccountUser < ActiveRecord::Base
    self.table_name = 'account_users'
  end

  class MigrationInbox < ActiveRecord::Base
    self.table_name = 'inboxes'
  end

  class MigrationInboxMember < ActiveRecord::Base
    self.table_name = 'inbox_members'
  end

  def up
    now = Time.current

    MigrationAccount.find_each do |account|
      inbox = account.inboxes.find_by(name: DEFAULT_INBOX_NAME)
      next unless inbox

      agent_ids = account.account_users.where.not(role: 1).pluck(:user_id)
      existing_agent_ids = MigrationInboxMember.where(
        inbox_id: inbox.id,
        user_id: agent_ids
      ).pluck(:user_id)
      missing_agent_ids = agent_ids - existing_agent_ids
      next if missing_agent_ids.blank?

      MigrationInboxMember.insert_all(
        missing_agent_ids.map do |user_id|
          {
            inbox_id: inbox.id,
            user_id: user_id,
            created_at: now,
            updated_at: now
          }
        end,
        unique_by: :index_inbox_members_on_inbox_id_and_user_id
      )
    end
  end

  def down
    # Intentionally no-op. Removing existing inbox access could lock active agents
    # out of production conversations after a rollback.
  end
end
