class Messages::NewMessageNotificationService
  pattr_initialize [:message!]

  def perform
    return unless message.notifiable?

    notify_conversation_assignee
    notify_participating_users
    notify_unassigned_inbox_members
  end

  private

  delegate :conversation, :sender, :account, to: :message

  def notify_conversation_assignee
    return if conversation.assignee.blank?
    return if already_notified?(conversation.assignee)
    return if conversation.assignee == sender

    NotificationBuilder.new(
      notification_type: 'assigned_conversation_new_message',
      user: conversation.assignee,
      account: account,
      primary_actor: message.conversation,
      secondary_actor: message
    ).perform
  end

  def notify_participating_users
    participating_users = conversation.conversation_participants.map(&:user)
    participating_users -= [sender] if sender.is_a?(User)

    participating_users.uniq.each do |participant|
      next if already_notified?(participant)

      NotificationBuilder.new(
        notification_type: 'participating_conversation_new_message',
        user: participant,
        account: account,
        primary_actor: message.conversation,
        secondary_actor: message
      ).perform
    end
  end

  def notify_unassigned_inbox_members
    return unless should_notify_unassigned_inbox_members?

    conversation.inbox.members.uniq.each do |agent|
      next if already_notified?(agent)

      NotificationBuilder.new(
        notification_type: 'participating_conversation_new_message',
        user: agent,
        account: account,
        primary_actor: message.conversation,
        secondary_actor: message
      ).perform
    end
  end

  def should_notify_unassigned_inbox_members?
    message.incoming? &&
      conversation.assignee.blank? &&
      whatsapp_notify_unassigned_inbox_ids.include?(conversation.inbox_id)
  end

  def whatsapp_notify_unassigned_inbox_ids
    ENV.fetch('WHATSAPP_NOTIFY_UNASSIGNED_INBOX_IDS', ENV.fetch('WHATSAPP_REOPEN_AS_PENDING_INBOX_IDS', ''))
       .split(',')
       .map(&:strip)
       .filter_map { |inbox_id| Integer(inbox_id, exception: false) }
  end

  # The user could already have been notified via a mention or via assignment
  # So we don't need to notify them again
  def already_notified?(user)
    conversation.notifications.exists?(user: user, secondary_actor: message)
  end
end
