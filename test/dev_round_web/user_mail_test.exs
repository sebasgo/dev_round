defmodule DevRoundWeb.UserMailTest do
  use DevRound.DataCase, async: false

  alias DevRoundWeb.UserMail

  import DevRound.EventsFixtures
  import DevRound.AccountsFixtures

  describe "attendance_changed_to_in_person/2" do
    test "builds an email to the affected user about the in-person change" do
      event = event_fixture() |> Repo.preload(:hosts)
      user = user_fixture(%{full_name: "Jane Doe", email: "jane@example.com"})

      email = UserMail.attendance_changed_to_in_person(user, event)

      assert [{"Jane Doe", "jane@example.com"}] = email.to

      assert email.subject ==
               "[DevRound] Your attendance for #{event.title} was changed to in-person"

      assert email.html_body =~ "in-person"
      assert email.html_body =~ event.title
    end
  end
end
