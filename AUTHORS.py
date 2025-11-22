""" Generate the AUTHORS.rst file from git commit history.

This module reads git commit logs and produces a formatted list of contributors
grouped by their contribution count, mapping email aliases and GitHub usernames.
"""

from dataclasses import dataclass
import math
import subprocess  # noqa: S404


def main() -> None:
    """ Generate and print the AUTHORS.rst content. """

    contributors = get_git_contributors()
    print_contributors(contributors)
# ------------------------------------------------------------------------------


EMAIL_ALIASES: dict[str, str | None] = {
    # Maintainers.
    "git@mikeboers.com": "github@mikeboers.com",
    "mboers@keypics.com": "github@mikeboers.com",
    "mikeb@loftysky.com": "github@mikeboers.com",
    "mikeb@markmedia.co": "github@mikeboers.com",
    "westernx@mikeboers.com": "github@mikeboers.com",
    # Junk.
    "mark@mark-VirtualBox.(none)": None,
    # Aliases.
    "a.davoudi@aut.ac.ir": "davoudialireza@gmail.com",
    "tcaswell@bnl.gov": "tcaswell@gmail.com",
    "xxr3376@gmail.com": "xxr@megvii.com",
    "dallan@pha.jhu.edu": "daniel.b.allan@gmail.com",
    "61652821+laggykiller@users.noreply.github.com": "chaudominic2@gmail.com",
}

CANONICAL_NAMES: dict[str, str] = {
    "caspervdw@gmail.com": "Casper van der Wel",
    "daniel.b.allan@gmail.com": "Dan Allan",
    "mgoacolou@cls.fr": "Manuel Goacolou",
    "mindmark@gmail.com": "Mark Reid",
    "moritzkassner@gmail.com": "Moritz Kassner",
    "vidartf@gmail.com": "Vidar Tonaas Fauske",
    "xxr@megvii.com": "Xinran Xu",
}

GITHUB_USERNAMES: dict[str, str] = {
    "billy.shambrook@gmail.com": "billyshambrook",
    "daniel.b.allan@gmail.com": "danielballan",
    "davoudialireza@gmail.com": "adavoudi",
    "github@mikeboers.com": "mikeboers",
    "jeremy.laine@m4x.org": "jlaine",
    "kalle.litterfeldt@gmail.com": "litterfeldt",
    "mindmark@gmail.com": "markreidvfx",
    "moritzkassner@gmail.com": "mkassner",
    "rush@logic.cz": "radek-senfeld",
    "self@brendanlong.com": "brendanlong",
    "tcaswell@gmail.com": "tacaswell",
    "ulrik.mikaelsson@magine.com": "rawler",
    "vidartf@gmail.com": "vidartf",
    "willpatera@gmail.com": "willpatera",
    "xxr@megvii.com": "xxr3376",
    "chaudominic2@gmail.com": "laggykiller",
    "wyattblue@auto-editor.com": "WyattBlue",
    "Curtis@GreenKey.net": "dotysan",
}


@dataclass
class Contributor:
    """ Represents a contributor with their email, names, and GitHub username. """

    email: str
    names: set[str]
    github: str | None = None
    commit_count: int = 0

    @property
    def display_name(self) -> str:
        """ Return the formatted display name for the contributor.

        Returns:
            Comma-separated sorted list of contributor names.
        """

        return ", ".join(sorted(self.names))

    def format_line(self, bullet: str) -> str:
        """ Format the contributor line for RST output.

        Args:
            bullet: The bullet character to use (- or *).

        Returns:
            Formatted RST line with contributor info.
        """

        if self.github:
            return (
                f"{bullet} {self.display_name} <{self.email}>; "
                f"`@{self.github} <https://github.com/{self.github}>`_"
            )
        return f"{bullet} {self.display_name} <{self.email}>"


def get_git_contributors() -> dict[str, Contributor]:
    """ Parse git log and return contributors grouped by canonical email.

    Returns:
        Dictionary mapping canonical emails to Contributor objects.
    """

    contributors: dict[str, Contributor] = {}
    git_log = subprocess.check_output(
        ["git", "log", "--format=%aN,%aE"],  # noqa: S607
        text=True,
    ).splitlines()

    for line in git_log:
        name, email = line.strip().rsplit(",", 1)
        canonical_email = EMAIL_ALIASES.get(email, email)

        if not canonical_email:
            continue

        if canonical_email not in contributors:
            contributors[canonical_email] = Contributor(
                email=canonical_email,
                names=set(),
                github=GITHUB_USERNAMES.get(canonical_email),
            )

        contributor = contributors[canonical_email]
        contributor.names.add(name)
        contributor.commit_count += 1

    for email, canonical_name in CANONICAL_NAMES.items():
        if email in contributors:
            contributors[email].names = {canonical_name}

    return contributors


def print_contributors(contributors: dict[str, Contributor]) -> None:
    """Print contributors grouped by logarithmic order of commits.

    Args:
        contributors: Dictionary of contributors to print.
    """

    print("""\
        Contributors
        ============

        All contributors (by number of commits):
        """.replace("        ", ""))

    sorted_contributors = sorted(
        contributors.values(),
        key=lambda c: (-c.commit_count, c.email),
    )

    last_order: int | None = None
    block_index = 0

    for contributor in sorted_contributors:
        # This is the natural log, because of course it should be. ;)
        order = int(math.log(contributor.commit_count))

        if last_order and last_order != order:
            block_index += 1
            print()
        last_order = order

        # The '-' vs '*' is so that Sphinx treats them as different lists, and
        # introduces a gap between them.
        bullet = "-*"[block_index % 2]
        print(contributor.format_line(bullet))


if __name__ == "__main__":
    main()
