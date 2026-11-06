class OrderApprovalsController < ApplicationController
  before_action :find_issue

  def create
    return render_404 unless HangoutsChat::OrderApproval.applicable?(@issue)

    if HangoutsChat::OrderApproval.approval_journal(@issue)
      flash[:warning] = l(:notice_order_already_approved)
    elsif !HangoutsChat::OrderApproval.approvable?(@issue)
      return deny_access
    else
      @issue.init_journal(User.current, HangoutsChat::OrderApproval::NOTE)
      if @issue.save
        flash[:notice] = l(:notice_order_approved)
      else
        flash[:error] = @issue.errors.full_messages.join(', ')
      end
    end
    redirect_to issue_path(@issue)
  end

  private

  def find_issue
    @issue = Issue.visible.find(params[:id])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
