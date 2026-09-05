defmodule DevRoundWeb.Admin.Event.RemoteParticipationTest do
  use DevRound.DataCase, async: false

  alias DevRound.Events
  alias DevRound.Events.EventAttendee

  import DevRound.EventsFixtures
  import DevRound.AccountsFixtures

  describe "on_item_updated/2" do
    test "converts remote attendees to local and emails them when remote is disabled" do
      import Swoosh.TestAssertions

      future_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)
      event = event_fixture(%{registration_deadline_local: future_deadline})
      remote_user = user_fixture(%{full_name: "Remote Ray", email: "ray@example.com"})

      {:ok, _} =
        Events.create_event_attendee(
          event,
          remote_user,
          %{"lang_ids" => [Enum.at(event.langs, 0).id], "is_remote" => "true"}
        )

      {:ok, event} = Events.update_event(event, %{allow_remote_participation: false})

      assert :sentinel = DevRoundWeb.Admin.EventLive.on_item_updated(:sentinel, event)

      attendee =
        Repo.get_by!(EventAttendee, event_id: event.id, user_id: remote_user.id)

      assert attendee.is_remote == false
      assert_email_sent(to: {"Remote Ray", "ray@example.com"})
    end

    test "does nothing when remote participation is still enabled" do
      import Swoosh.TestAssertions

      future_deadline = NaiveDateTime.add(NaiveDateTime.local_now(), 12, :hour)
      event = event_fixture(%{registration_deadline_local: future_deadline})
      remote_user = user_fixture(%{full_name: "Remote Sam", email: "sam@example.com"})

      {:ok, _} =
        Events.create_event_attendee(
          event,
          remote_user,
          %{"lang_ids" => [Enum.at(event.langs, 0).id], "is_remote" => "true"}
        )

      assert :sentinel = DevRoundWeb.Admin.EventLive.on_item_updated(:sentinel, event)

      attendee =
        Repo.get_by!(EventAttendee, event_id: event.id, user_id: remote_user.id)

      assert attendee.is_remote == true
      refute_email_sent(to: {"Remote Sam", "sam@example.com"})
    end
  end
end
