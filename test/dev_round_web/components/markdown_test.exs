defmodule DevRoundWeb.MarkdownTest do
  use ExUnit.Case, async: true
  import Phoenix.Component
  import Phoenix.LiveViewTest
  import DevRoundWeb.CoreComponents, only: [markdown: 1]

  describe "markdown/1 component" do
    test "renders nil as empty string" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.markdown markdown={nil} />
        """)

      assert String.trim(html) == ""
    end

    test "renders empty string" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.markdown markdown="" />
        """)

      assert String.trim(html) == ""
    end

    test "renders basic CommonMark elements" do
      assigns = %{
        input: """
        # Heading 1
        ## Heading 2

        This is a **bold** paragraph with *italic* text and [a link](https://example.com).

        - Item 1
        - Item 2
        """
      }

      html =
        rendered_to_string(~H"""
        <.markdown markdown={@input} />
        """)

      assert html =~ "<h1>Heading 1</h1>"
      assert html =~ "<h2>Heading 2</h2>"
      assert html =~ "<strong>bold</strong>"
      assert html =~ "<em>italic</em>"
      assert html =~ ~s(<a href="https://example.com">a link</a>)
      assert html =~ "<ul>"
      assert html =~ "<li>Item 1</li>"
      assert html =~ "<li>Item 2</li>"
    end

    test "renders code blocks with language classes for highlighting" do
      assigns = %{
        input: """
        ```elixir
        def hello do
          :world
        end
        ```
        """
      }

      html =
        rendered_to_string(~H"""
        <.markdown markdown={@input} />
        """)

      assert html =~ ~s(<pre><code class="language-elixir">)
      assert html =~ "def hello do"
    end

    test "renders superscript" do
      assigns = %{
        input: "Einstein said E = mc^2^ and 10^5^ is large."
      }

      html =
        rendered_to_string(~H"""
        <.markdown markdown={@input} />
        """)

      assert html =~ "E = mc<sup>2</sup>"
      assert html =~ "10<sup>5</sup>"
    end

    test "renders subscript" do
      assigns = %{
        input: "Water is H~2~O and glucose is C~6~H~12~O~6~."
      }

      html =
        rendered_to_string(~H"""
        <.markdown markdown={@input} />
        """)

      assert html =~ "H<sub>2</sub>O"
      assert html =~ "C<sub>6</sub>H<sub>12</sub>O<sub>6</sub>"
    end

    test "renders footnotes" do
      assigns = %{
        input: """
        Here is a statement with a footnote[^1] and another[^second].

        [^1]: This is the first footnote.
        [^second]: This is the second footnote.
        """
      }

      html =
        rendered_to_string(~H"""
        <.markdown markdown={@input} />
        """)

      assert html =~ ~s(class="footnote-ref")
      assert html =~ ~s(<a href="#fn-1")
      assert html =~ ~s(<section class="footnotes")
      assert html =~ "This is the first footnote."
      assert html =~ "This is the second footnote."
    end

    test "renders tables" do
      assigns = %{
        input: """
        | Language | Paradigm |
        | :--- | :--- |
        | Elixir | Functional |
        | Rust | Multi-paradigm |
        """
      }

      html =
        rendered_to_string(~H"""
        <.markdown markdown={@input} />
        """)

      assert html =~ "<table>"
      assert html =~ "<th align=\"left\">Language</th>"
      assert html =~ "<td align=\"left\">Elixir</td>"
    end

    test "renders strikethrough, autolinks, and task lists" do
      assigns = %{
        input: """
        ~~strikethrough~~

        https://elixir-lang.org

        - [x] Done task
        - [ ] Pending task
        """
      }

      html =
        rendered_to_string(~H"""
        <.markdown markdown={@input} />
        """)

      assert html =~ "<del>strikethrough</del>"
      assert html =~ ~s(<a href="https://elixir-lang.org">https://elixir-lang.org</a>)
      assert html =~ ~s(type="checkbox")
    end

    test "does not render raw HTML tags when unsafe rendering is disabled" do
      assigns = %{
        input: """
        <div class="custom-alert">Important announcement</div>
        """
      }

      html =
        rendered_to_string(~H"""
        <.markdown markdown={@input} />
        """)

      refute html =~ ~s(<div class="custom-alert">)
    end
  end
end
