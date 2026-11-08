class GroupsController < InertiaController
  rate_limit to: 20, within: 1.minute, only: :join, by: -> { current_user.id }, store: RATE_LIMIT_STORE,
    with: -> { render_error(429, "Too many invitation attempts. Please try again in a minute.") }

  def index
    groups = current_user.groups.includes(:memberships).order(:name, :id).map do |group|
      group.as_json(only: [ :id, :name, :owner_id ]).merge(member_count: group.memberships.size)
    end
    render inertia: "groups/index", props: { groups: groups }
  end

  def new
    render inertia: "groups/new"
  end

  def create
    group = Group.create_with_owner!(owner: current_user, name: params.permit(:name)[:name])
    redirect_to group_path(group), notice: "Your group is ready. Invite a friend!", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    redirect_to new_group_path, inertia: { errors: error.record.errors }, status: :see_other
  end

  def show
    group = current_user.groups.find(params[:id])
    details = group.as_json(only: [ :id, :name, :owner_id ]).merge(
      members: group.members.order(:display_name, :id).as_json(only: [ :id, :display_name ])
    )
    details[:invitation_code] = group.invite_code if group.owner_id == current_user.id
    render inertia: "groups/show", props: { group: details }
  end

  def join_form
    render inertia: "groups/join"
  end

  def join
    code = params.permit(:code)[:code].to_s.strip.upcase
    group = Group.find_by(invite_code: code)
    return invalid_invitation unless group

    # Joining and resetting use the same row lock, so an old code cannot join
    # after a reset has completed, and repeated joins create one membership.
    group.with_lock do
      return invalid_invitation unless group.invite_code == code

      group.memberships.find_or_create_by!(user: current_user)
    end
    redirect_to group_path(group), notice: "You are a member of #{group.name}.", status: :see_other
  end

  private

  def invalid_invitation
    redirect_to join_groups_path, inertia: { errors: { code: [ "This invitation code is invalid or has been replaced." ] } }, status: :see_other
  end
end
