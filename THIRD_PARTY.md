# keybr language data and lesson generation

Upstream: https://github.com/aradzie/keybr.com
Revision: `05a37bc5265f65ff538c59c613db29442f345d51`
Retrieved: 2026-10-01
Copyright: keybr.com contributors.
License: GNU Affero General Public License, version 3. The complete upstream license is included in `licenses/keybr-AGPL-3.0.txt`.

`EnglishData.js` contains converted English and British English word lists, four-gram transition tables, and the decoded English exclusion list from:

- `packages/keybr-content-words/lib/data/words-en.json` and `words-en-GB.json`
- `packages/keybr-phonetic-model/assets/model-en.data` and `model-en-GB.data`
- `packages/keybr-phonetic-model/lib/blacklist/blacklist-en.json`

The converter `tools/import-keybr.py` preserves word frequency ordering and phonetic transition weights, removes excluded words, and restricts natural words to 3–12 ASCII letters. Run it with a checkout of the pinned upstream revision to regenerate the data.

`WordGenerator.js` adapts the algorithms in `packages/keybr-lesson/lib/guided.ts`, `dictionary.ts`, `text/words.ts`, and `packages/keybr-phonetic-model/lib/phoneticmodel.ts` to QML JavaScript. These adapted/generated files are provided under AGPL-3.0.

Local changes: bounded phonetic retries; unique fallback candidates; a shuffled word pool instead of independent random draws; saved recent-word history across exercises; UK spelling when UK ISO is selected; numeric/symbol practice using dictionary words with the focused character. The existing unlocking thresholds, four-line display, code exercises and user progress are retained.

Upstream's natural-words mode selects up to 1,000 matching dictionary words and supplements pools smaller than 15 using phonetic generation. Omatype follows that approach; it does not inject phonetic words into sufficiently large natural-word pools. With very few unlocked letters, repetition and occasional phonetic words remain necessary.
