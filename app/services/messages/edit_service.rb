class Messages::EditService
  EDIT_WINDOW = 15.minutes

  class Error < StandardError; end

  def initialize(message, content)
    @message = message
    @content = content.to_s
  end

  def perform
    validate!

    @message.update!(
      content: @content,
      content_attributes: @message.content_attributes.to_h.merge(
        'edited' => true,
        'edited_at' => Time.current.iso8601
      )
    )

    @message
  end

  private

  def validate!
    raise Error, 'Only outgoing messages can be edited' unless @message.outgoing?
    raise Error, 'Private messages cannot be edited' if @message.private?
    raise Error, 'Only text messages without attachments can be edited' unless @message.content_type == 'text' && @message.attachments.empty?
    raise Error, 'Deleted messages cannot be edited' if @message.deleted
    raise Error, 'Failed messages cannot be edited' if @message.failed?
    raise Error, 'The message edit window has expired' if @message.created_at < EDIT_WINDOW.ago
    raise Error, 'Message content cannot be empty' if @content.strip.blank?
    raise Error, 'The message has not changed' if @content == @message.content
  end
end
