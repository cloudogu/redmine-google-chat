module HangoutsChat
  class OrderApprovalHook < Redmine::Hook::ViewListener
    render_on :view_issues_show_details_bottom, :partial => 'hangouts_chat/order_approval'
  end
end
