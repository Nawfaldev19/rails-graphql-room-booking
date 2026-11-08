# Third-party notices

Room Booking's own code is under the [MIT licence](LICENSE). It depends on the gems and
packages below. Each stays under its own licence, and the full licence text ships
inside each gem or package after installation.

Only permissive licences are used: MIT, ISC, Apache-2.0, BSD and the Ruby licence
for code, and the SIL Open Font License for fonts. Both dependency trees, including
indirect dependencies, were scanned when this file was written.

Three notes on the Ruby tree:

- Gems maintained with Ruby itself are offered under "BSD-2-Clause or Ruby". They
  are used under BSD-2-Clause.
- `rdoc` (pulled in by Rails through `irb`) is offered under "Ruby or
  GPL-2.0-only". It is used under the Ruby licence.
- `diff-lcs` (pulled in by RSpec) is offered under "MIT or Artistic-1.0-Perl or
  GPL-2.0-or-later". It is used under MIT.

## Ruby gems

| Gem     | Version | Licence      | Source                                          |
| ------- | ------- | ------------ | ----------------------------------------------- |
| rails   | 8.1.4   | MIT          | <https://rubyonrails.org>                       |
| graphql | 2.6.11  | MIT          | <https://github.com/rmosolgo/graphql-ruby>      |
| sqlite3 | 2.9.6   | BSD-3-Clause | <https://github.com/sparklemotion/sqlite3-ruby> |
| puma    | 8.0.2   | BSD-3-Clause | <https://puma.io>                               |
| bcrypt  | 3.1.22  | MIT          | <https://github.com/bcrypt-ruby/bcrypt-ruby>    |

Development and test only:

| Gem           | Version | Licence |
| ------------- | ------- | ------- |
| rspec-rails   | 8.0.4   | MIT     |
| rubocop       | 1.92.0  | MIT     |
| rubocop-rails | 2.38.0  | MIT     |
| rubocop-rspec | 3.10.2  | MIT     |
| simplecov     | 1.3.2   | MIT     |

## JavaScript packages

| Package      | Version | Licence |
| ------------ | ------- | ------- |
| gql.tada     | 1.11.4  | MIT     |
| graphql      | 16.14.2 | MIT     |
| lucide-react | 1.55.0  | ISC     |
| react        | 19.3.0  | MIT     |
| react-dom    | 19.3.0  | MIT     |
| react-router | 7.18.4  | MIT     |
| urql         | 5.0.4   | MIT     |

Development and test only:

| Package                     | Version  | Licence    |
| --------------------------- | -------- | ---------- |
| @eslint/js                  | 9.39.5   | MIT        |
| @playwright/test            | 1.64.0   | Apache-2.0 |
| @testing-library/jest-dom   | 6.9.1    | MIT        |
| @testing-library/react      | 16.3.3   | MIT        |
| @testing-library/user-event | 14.6.7   | MIT        |
| @types/node                 | 20.19.43 | MIT        |
| @types/react                | 19.3.0   | MIT        |
| @types/react-dom            | 19.3.0   | MIT        |
| @vitejs/plugin-react-swc    | 4.3.3    | MIT        |
| @vitest/coverage-v8         | 4.1.11   | MIT        |
| concurrently                | 9.2.5    | MIT        |
| eslint                      | 9.39.5   | MIT        |
| eslint-plugin-react-hooks   | 5.2.0    | MIT        |
| globals                     | 17.13.0  | MIT        |
| jsdom                       | 29.1.1   | MIT        |
| prettier                    | 3.9.10   | MIT        |
| typescript                  | 6.0.3    | Apache-2.0 |
| typescript-eslint           | 8.71.1   | MIT        |
| vite                        | 7.3.7    | MIT        |
| vitest                      | 4.1.11   | MIT        |

## Fonts

All three are under the SIL Open Font License 1.1 and are bundled through the
Fontsource packages, so no font is loaded from another site.

| Font            | Used for                     | Package                              | Version |
| --------------- | ---------------------------- | ------------------------------------ | ------- |
| Fraunces        | Headings                     | @fontsource-variable/fraunces        | 5.3.0   |
| Instrument Sans | Body text                    | @fontsource-variable/instrument-sans | 5.3.0   |
| JetBrains Mono  | Times, code and message text | @fontsource-variable/jetbrains-mono  | 5.3.0   |

## Icons and images

- Interface icons come from Lucide (`lucide-react`, ISC licence).
- `public/favicon.svg` is original work and is covered by this project's licence.

## Packages left out on purpose

Some common tools were not used because their licences are outside the list above:
an accessibility lint plugin (it depends on an MPL-2.0 engine), the usual GraphQL
code generator (it pulls in CC-BY-4.0 browser data) and Vite 8 (it depends on an
MPL-2.0 CSS engine; Vite 7 does not).
