import { describe, expect, it } from "vitest";
import { render } from "@testing-library/react";
import { Markdown } from "@multica/ui/markdown";
import { ReadonlyContent } from "./readonly-content";

// Finance copy with multiple `$` amounts and `~` (approximately) markers.
// With remark-math's default single-dollar parsing, the text between two
// dollar amounts is swallowed into a KaTeX inline-math span and rendered
// in an italic math font (see SEN-667).
const FINANCE_TEXT =
  "MRR ≈ $280/mo gross (~$185 net of Apple's cut), 41 active paid subscriptions";

describe("dollar amounts in markdown", () => {
  it("Markdown renders $ amounts as plain text, not inline math", () => {
    const { container } = render(<Markdown>{FINANCE_TEXT}</Markdown>);
    expect(container.querySelector(".katex")).toBeNull();
    expect(container.textContent).toContain(
      "$280/mo gross (~$185 net of Apple's cut)",
    );
  });

  it("ReadonlyContent renders $ amounts as plain text, not inline math", () => {
    const { container } = render(<ReadonlyContent content={FINANCE_TEXT} />);
    expect(container.querySelector(".katex")).toBeNull();
    expect(container.textContent).toContain(
      "$280/mo gross (~$185 net of Apple's cut)",
    );
  });

  it("still renders explicit $$ display math", () => {
    const { container } = render(<Markdown>{"$$\nE = mc^2\n$$"}</Markdown>);
    expect(container.querySelector(".katex")).not.toBeNull();
  });
});
