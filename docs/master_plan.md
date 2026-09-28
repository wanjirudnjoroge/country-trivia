# Country Trivia — Master Plan

**Project:** `country-trivia` (Flutter 3.44 / Dart 3.12, stable)
**Architecture:** MVVM with `provider` (`ChangeNotifier` ViewModels)
**Targets:** Android, iOS, Web (phone-first, responsive up to desktop)
**Status:** Plan approved for implementation — no app code written against this spec yet.

---

## 1. Goal & Rules of the Game

The player is shown a country flag and four country names. Exactly one is correct. The player
taps a name to answer.

### 1.1 Attempts & scoring (core rule)

Each question allows **3 scoring attempts**, then a reveal:

| Attempt | Event                                | Points |
| ------- | ------------------------------------ | -----: |
| 1st     | Tap correct answer                   |     10 |
| 2nd     | Tap wrong, then tap correct answer   |      8 |
| 3rd     | Tap wrong, then tap correct answer   |      5 |
| 4th tap | Tap wrong with no attempts remaining |      0 |

- Tapping wrong **consumes** an attempt and immediately reveals that the tapped option is
  incorrect (red), while the still-unselected options remain tappable.
- After the 3rd failed attempt the question is **locked**: the correct option is highlighted
  green, all options are disabled, 0 points are awarded.
- Points are awarded **only** when the correct option is tapped. A revealed answer never scores.
- Maximum possible points per question = 10. Maximum score = `10 × questionCount`.

The point ladder is data, not code: `QuizConfig.pointsLadder = [10, 8, 5]`, indexed by
attempts already used. Changing the ladder or the attempt count requires no logic changes.

### 1.2 Session

- `questionCount = 10` questions per run (configurable — see [§11 Open Questions](#11-open-questions--decisions-needed)).
- Score, current question index, best streak, and a per-question summary are tracked.
- After the last question, a final score screen shows total score, correct-on-first-try count,
  best streak, and a **Play again** button that restarts a fresh run.

---

## 2. Verified External Dependencies

Both external services were probed live before writing this plan. **Do not re-derive these
values; they are measured.**

### 2.1 Country data — countriesnow.space

The supplied Postman documentation
(`https://documenter.getpostman.com/view/1134062/T1LJjU52`, collection
*"Countries & Cities API"*) is only a wrapper: every request is templated with
`{{devURL}}{{baseEndpoint}}`, and the values live in the published environment
`countries_cities prod` (recovered from the documenter metadata endpoint). Resolved:

```
devURL       = https://countriesnow.space
baseEndpoint = /api/v0.1/countries
```

**Endpoint used by this app:**

```
GET https://countriesnow.space/api/v0.1/countries/flag/images
```

Verified 200 response (truncated):

```json
{
  "error": false,
  "msg": "flags images retrieved",
  "data": [
    { "name": "Afghanistan", "flag": "https://upload.wikimedia.org/.../Flag_of_Afghanistan.svg", "iso2": "AF", "iso3": "AFG" },
    { "name": "Albania",      "flag": "https://upload.wikimedia.org/.../Flag_of_Albania.svg",      "iso2": "AL", "iso3": "ALB" }
  ]
}
```

Measured properties:

| Property        | Value                                                              |
| --------------- | ------------------------------------------------------------------ |
| Countries       | **222** (returned in full with no `limit` parameter)                |
| Payload size    | ~29 KB uncompressed — small enough to fetch once and cache          |
| Auth            | None. No API key, no rate limit observed                            |
| CORS            | `access-control-allow-origin: *` → **works unchanged in a browser** |
| Caching         | `cache-control: max-age=86400` (24 h)                               |
| `iso2` quality  | 222/222 present, **222 unique**, all uppercase                     |

**Fields actually consumed: `name` and `iso2`.** The API's own `flag` field points at
Wikimedia `.svg` files; per the spec, flags come from flagcdn instead, so `flag` is ignored.

Parsing risks (must be handled defensively in the data layer):

- The sibling `/iso` endpoint in the same collection returns `Iso2` / `Iso3` with a capital
  `I`. Our endpoint returns lowercase `iso2`, but the mapper should not be written so tightly
  that a casing change upstream silently yields 0 countries.
- The response is not a bare array — it is an envelope (`error`, `msg`, `data`). Never
  `jsonDecode(...) as List`.
- Entries missing a blank `name` or `iso2` must be dropped, not crash the parse.

### 2.2 Flag images — flagcdn

```
https://flagcdn.com/w320/{iso2_lowercase}.png
```

Verified: **all 222 `iso2` codes returned by the API resolve to HTTP 200 on flagcdn** — the
two services are fully compatible and no per-country fallback list is needed.

**The spec's `http://` URL is used over `https://` instead.** Reason: `http://flagcdn.com/...`
answers `301 → https://flagcdn.com/...`. Native clients would follow the redirect, but a web
build served over HTTPS gets the request blocked as mixed content *before* the redirect can
happen. The scheme is a single constant (`FlagService.baseUrl`) so the spec intent is preserved
and reverting is a one-line change.

### 2.3 Consequences for the HTTP client

Flutter web **cannot** use `dart:io`'s `HttpClient`. The data layer therefore uses
`package:http`, which transparently resolves to `IOClient` on mobile and `BrowserClient` on web
from the same `http.get(...)` call. No `kIsWeb` branching, no conditional imports.

---

## 3. Package Strategy

Only two new runtime dependencies, both justified by the spec or by §2.3.

| Package    | Why it is required                                                                 |
| ---------- | ---------------------------------------------------------------------------------- |
| `provider` | Explicitly mandated for state management.                                            |
| `http`     | Only cross-platform HTTP client that works on web **and** mobile without branching.  |

Explicitly **not** added: `dio` (no interceptor need), `get_it`/`injectable` (a hand-rolled
`MultiProvider` graph is enough at this size), `cached_network_image` (`Image.network` +
`loadingBuilder` + `errorBuilder` covers the requirement), `intl` (no localisation yet),
`mocktail`/`build_runner` (`package:http` ships `MockClient`; fake ViewModels are hand-written).

Test-only additions: none. `flutter_test` + `flutter_lints` (already present) are sufficient.

---

## 4. Layered Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│  VIEW    lib/screens/ · lib/widgets/                                     │
│  Pure Flutter. No business rules, no HTTP, no mutation of game state.    │
│  Renders a QuizViewState snapshot; forwards user intent to the VM.       │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │  context.watch / context.select / context.read
┌───────────────────────────────▼──────────────────────────────────────────┐
│  VIEWMODEL   lib/viewmodels/                                             │
│  ChangeNotifier. Owns all game state + state machine. Pure logic:       │
│  no BuildContext, no Widgets, no dart:io, no direct JSON.                │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │  calls Repository interface
┌───────────────────────────────▼──────────────────────────────────────────┐
│  MODEL    lib/models/                                                    │
│  Immutable value types: Country, Question, AnswerOutcome, GameResult,   │
│  QuizConfig. fromJson only where data crosses the network boundary.     │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │  implemented by
┌───────────────────────────────▼──────────────────────────────────────────┐
│  DATA / REPOSITORY   lib/data/                                          │
│  ApiClient (package:http) · CountryRemoteDataSource (DTO→Model)        │
│  CountryRepository (interface + Remote impl + Static fallback)          │
│  QuestionGenerator (pure: build N questions, shuffle distractors)      │
│  countries.dart (offline fallback list, no network)                     │
└──────────────────────────────────────────────────────────────────────────┘
```

**Dependency rule:** arrows point downward only. `models` imports nothing but `dart:core`
(+ `data/countries.dart` nowhere — the fallback list is read by the repository, not the model).
`data` never imports `viewmodels` or `screens`. `viewmodels` never import `screens`.
A `viewmodels` unit test must be runnable with zero Flutter bindings.

### 4.1 Why `ChangeNotifier` and not `ValueNotifier`/`Bloc`

- MVVM's ViewModel *is* a notification source; `ChangeNotifier` is the idiomatic Flutter
  expression of that, and the spec asks for provider.
- State here is a single small object mutated through a well-defined set of intents
  (`selectOption`, `next`, `restart`) — the classic case where a full event/cubit stream adds
  boilerplate without buying correctness.
- `ChangeNotifier` + `context.select` still gives fine-grained rebuilds (see §7.3).

---

## 5. File Layout

```
lib/
├── main.dart                       # Composition root: MultiProvider + MaterialApp
├── app.dart                        # CountryTriviaApp (theme, routes)
├── core/
│   ├── app_config.dart             # dart-define backed config (API base, timeouts)
│   ├── app_theme.dart              # Material 3 ColorScheme, component themes
│   ├── app_routes.dart             # named routes: / and /results
│   └── result.dart                 # sealed Result<T> / Failure for error handling
├── models/
│   ├── country.dart                # Country { name, iso2, iso3, flagUrl }
│   ├── question.dart               # Question { country, options, correctIndex, ... }
│   ├── answer_outcome.dart         # enum + points resolution for an attempt
│   ├── question_result.dart        # per-question outcome (for the summary)
│   └── game_result.dart            # GameResult { score, correct, bestStreak, ... }
├── data/
│   ├── api_client.dart             # thin wrapper over package:http + Result<T>
│   ├── country_dto.dart            # wire model + defensive fromJson
│   ├── country_remote_data_source.dart
│   ├── country_repository.dart     # abstract CountryRepository
│   ├── remote_country_repository.dart
│   ├── static_country_repository.dart
│   ├── question_generator.dart     # pure question construction
│   └── countries.dart              # 189-country offline fallback (name + iso2)
├── viewmodels/
│   ├── quiz_view_model.dart        # game state machine + score/streak
│   └── load_state.dart             # idle | loading | ready | error
├── screens/
│   ├── quiz_screen.dart            # the game
│   └── results_screen.dart         # final score + Play again
└── widgets/
    ├── flag_image.dart             # network flag: loading + error fallback + retry
    ├── answer_option_tile.dart     # one option, idle/correct/wrong/disabled states
    ├── attempts_indicator.dart     # "2 of 3 attempts left"
    ├── score_header.dart           # score, streak, progress
    └── feedback_banner.dart        # "Correct! +10" / "Wrong — try again" / reveal
```

Tests mirror the tree under `test/`.

---

## 6. Model Design

### 6.1 `Country`

```dart
class Country {
  const Country({required this.name, required this.iso2, this.iso3});
  final String name;    // "Japan"
  final String iso2;    // "JP" (stored uppercase; normalised on parse)
  final String? iso3;   // "JPN" — unused by the quiz, kept for the summary

  String get iso2Lowercase => iso2.toLowerCase();
  String get flagUrl => '${FlagService.baseUrl}$iso2Lowercase.png';
  // == and hashCode by iso2 (stable identity across repository reloads)
}
```

`flagUrl` is a computed getter, never a stored field — the CDN base is config, not data.

### 6.2 `Question`

Immutable. One question = one correct country + 4 option countries (1 correct, 3 distractors),
shuffled so the correct index is uniformly distributed.

```dart
class Question {
  const Question({required this.country, required this.options, required this.correctIndex});
  final Country country;
  final List<Country> options;   // always length 4, correctIndex inside
  final int correctIndex;
  bool isCorrect(int index) => index == correctIndex;
}
```

Invariants enforced by `QuestionGenerator` and asserted in unit tests:
`options.length == 4`, `correctIndex` in range, no duplicate countries,
`options[correctIndex] == country`, correct index not always the same position across a run.

### 6.3 `AnswerOutcome` and `GameResult`

```dart
enum AnswerStatus { correct, wrong, exhausted }   // exhausted = 3 attempts used up

class AnswerOutcome {
  final int questionIndex;
  final AnswerStatus status;
  final int? selectedIndex;      // null when the question was revealed
  final int attemptsUsed;        // 1..3 (or 0 if never tapped)
  final int pointsAwarded;       // 0, 10, 8, or 5
  final bool solvedOnFirstTry;
}

class GameResult {
  final int score;               // sum of pointsAwarded
  final int questionCount;
  final int solvedOnFirstTry;
  final int solvedEventually;    // solved using a later attempt
  final int revealed;            // never solved → correct answer shown, 0 points
  final int bestStreak;
  final List<AnswerOutcome> outcomes;
}
```

`GameResult` is a snapshot produced once at the end of a run and handed to the results screen,
so the results screen cannot accidentally mutate live game state.

---

## 7. State Management (provider)

### 7.1 Composition root — `main.dart`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = ApiClient(http.Client(), baseUrl: AppConfig.apiBaseUrl);
  final remote = RemoteCountryRepository(CountryRemoteDataSource(apiClient));
  runApp(
    MultiProvider(
      providers: [
        Provider<CountryRepository>(create: (_) => FallbackCountryRepository(remote, countries)),
        ChangeNotifierProvider<QuizViewModel>(
          create: (ctx) => QuizViewModel(generator: QuestionGenerator(ctx.read<CountryRepository>()))
            ..startNewGame(),
        ),
      ],
      child: const CountryTriviaApp(),
    ),
  );
}
```

Dependencies are injected through constructors, so every ViewModel and repository is
substitutable in tests. `http.Client` is created once and closed on app teardown; it is
*not* created per request (connection reuse on mobile).

### 7.2 `QuizViewModel` — the state machine

```dart
class QuizViewModel extends ChangeNotifier {
  LoadState _loadState = LoadState.idle;
  List<Question> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  int _attemptsUsed = 0;
  int? _selectedIndex;          // null = not answered yet
  AnswerStatus? _lastStatus;
  final List<AnswerOutcome> _outcomes = [];
  String? _errorMessage;
  bool get isAnswered => _selectedIndex != null && !_canStillAnswer;
  bool get canStillAnswer => _attemptsUsed < QuizConfig.attemptsPerQuestion;
  bool get isLastQuestion => _currentIndex == _questions.length - 1;
}
```

**Public intents (the only way state changes):**

| Method                   | Guard                                       | Effect |
| ------------------------ | ------------------------------------------- | ------ |
| `startNewGame()`         | always                                      | fetch countries, generate 10 questions, reset all counters |
| `selectOption(int i)`    | `canStillAnswer && !isLocked`               | evaluate, score, update streak, `notifyListeners()` |
| `next()`                 | `isAnswered`                                | append `AnswerOutcome`, advance index, reset per-question state |
| `restart()`              | always                                      | alias of `startNewGame()`, bound to *Play again* |
| `retryLoad()`            | `loadState == error`                        | re-fetch after a startup failure |

**Per-question transition table:**

| Current  | Event (option `i` tapped)         | Guard passes            | Next state | Points | Streak |
| -------- | -------------------------------- | ----------------------- | ---------- | -----: | -----: |
| `open`   | `i == correctIndex`               | yes                     | `correct`  |    10/8/5 | +1 |
| `open`   | `i != correctIndex`, attempts < 2 | yes                     | `open`     |     0 | reset to 0 |
| `open`   | `i != correctIndex`, attempts = 2 | yes                     | `exhausted`|     0 | reset to 0 |
| `correct`| any tap                          | no (locked)             | `correct`  |     — |     — |
| `exhausted` | any tap                       | no (locked)             | `exhausted`|     — |     — |

The points rule lives in exactly one place:

```dart
int pointsFor(int attemptsUsedBeforeThisTap) =>
    attemptsUsedBeforeThisTap < QuizConfig.pointsLadder.length
        ? QuizConfig.pointsLadder[attemptsUsedBeforeThisTap]
        : 0;
```

**Streak semantics:** a streak increments on any correct tap and resets on any wrong tap.
Best streak = the maximum value reached. (Open question Q3 — the spec's streak definition is
not restated in the latest brief.)

### 7.3 Rebuild discipline

- Views call `context.watch<QuizViewModel>()` only at the top of the screen.
- Expensive/independent subtrees use `context.select<QuizViewModel, int>((vm) => vm.score)` so
  a `next()` does not repaint the flag image.
- `AnimatedSwitcher` keyed on `_currentIndex` fades/slides the flag and options between
  questions without leaking listeners.
- No `ValueListenableBuilder`/`setState` in views — views are stateless and rebuild from the
  ViewModel. (`setState` is permitted only for genuinely view-local state such as text-field
  focus; the quiz has none.)

### 7.4 Navigation

Named routes, no third-party router:

- `/` → `QuizScreen` (owns no state; reads the single app-scoped `QuizViewModel`).
- `/results` → `ResultsScreen(gameResult: ...)`, pushed via `Navigator.pushNamed` when
  `isLastQuestion && isAnswered` and *Next* is pressed. The result object is passed once, so
  the results screen is a pure function of its input.
- *Play again* → `Navigator.pop()` back to `/`, then `vm.restart()`. The app-scoped ViewModel
  resets in place, so no rebuild of the provider tree and no lost scroll/animation state.

---

## 8. Data Layer Detail

```dart
class CountryRemoteDataSource {
  CountryRemoteDataSource(this._api, {required this.path});
  final ApiClient _api;

  Future<Result<List<Country>>> fetchCountries() async {
    final result = await _api.getJson(path);          // Result<Map<String, dynamic>>
    return result.map(parseCountryList);               // Result<List<Country>>
  }
}
```

- `ApiClient` owns `http.Client`, the base URL, and a `Duration` timeout (10 s). It converts
  `SocketException`, `TimeoutException`, `ClientException`, and non-2xx statuses into typed
  `Failure` values — **no exception escapes the data layer**.
- `parseCountryList` tolerates both a bare `List` and the `{error, msg, data}` envelope, and
  skips malformed entries, returning a `Failure` if fewer than 4 usable countries remain
  (below that the quiz cannot build a single question).
- `QuestionGenerator` uses `Random.secure()`-backed `Random` and shuffles both the question
  order and the option order. Distractors are sampled without replacement.
- **Fallback chain:** `FallbackCountryRepository` tries remote, and on any `Failure` falls back
  to `StaticCountryRepository` (the checked-in `lib/data/countries.dart` list, 189 countries,
  already verified to have valid flagcdn codes). The UI can then show a non-blocking
  "Offline — using built-in country list" banner instead of a dead end. This also satisfies
  the earlier requirement to keep a curated list in `lib/data/countries.dart`.
- Success is cached in memory for the process lifetime; the CDN/API `max-age=86400` makes a
  second fetch pointless within a session.

### 8.1 Repository interface

```dart
abstract class CountryRepository {
  Future<Result<List<Country>>> getCountries({bool forceRefresh = false});
}
```

`Result<T>` is a sealed type (`Ok<T>` / `Err<Failure>`) in `lib/core/result.dart`, so error
handling is exhaustive and the ViewModel never needs `try/catch`.

---

## 9. UI Design

### 9.1 Screens

**`QuizScreen`**
- App bar: title *Country Trivia*, score chip, streak chip.
- Linear progress indicator: "Question 3 of 10".
- **Flag card**: 4:3 rounded card, max width 420, `AspectRatio(4/3)`, subtle elevation.
- **Attempts indicator**: three pips, filled = used; turns amber on the last attempt.
- **Four option tiles**: label letter (A–D) + country name.
- **Feedback banner**: appears under the flag on answer.
- **Next button**: full width, disabled until the question is resolved.

Tile states (all four rendered from the same widget, driven by the ViewModel):

| State                | Background   | Border     | Text     | Interaction |
| -------------------- | ------------ | ---------- | -------- | ----------- |
| idle                 | surface      | outline    | onSurface| tappable    |
| hovered/focused      | secondary    | outline    | onSurface| tappable    |
| selected correct     | **green**    | green      | onGreen  | locked      |
| selected wrong       | **red**      | red        | onRed    | locked      |
| unselected after an answer | neutral | outline | dimmed  | locked      |
| correct after reveal | **green**    | green      | onGreen  | locked      |

Green/red come from a `ColorScheme` extension with explicit `success`/`error` roles, not raw
`Colors.green`/`Colors.red`, so both light and dark themes stay accessible (and so the colours
are not at odds with Material 3's own green/red semantics). Correct/wrong states are also
distinguished by an icon and by a border, never by colour alone.

**`ResultsScreen`**
- Big score, "You scored X / 10 points" with a max-of-`questionCount × 10` denominator.
- Stat row: correct on first try, solved after a wrong guess, revealed, best streak.
- A one-line grade: *Flawless* 10/10 · *Excellent* ≥ 8 · *Good* ≥ 6 · *Keep practising* < 6.
- **Play again** (filled) and *Quit* (text) buttons.

### 9.2 `FlagImage` — loading, error, retry

```dart
Image.network(
  country.flagUrl,
  fit: BoxFit.contain,
  loadingBuilder: (context, child, progress) =>
      progress == null ? child : _Spinner(progress: progress.expectedTotalBytes),
  errorBuilder: (context, error, stack) => _FlagError(code: country.iso2Lowercase, onRetry: _reload),
  gaplessPlayback: true,   // avoids a flash of empty space between questions
)
```

- **Loading:** a centred `CircularProgressIndicator` with the country code beneath it, so the
  player can already read the code while the image arrives.
- **Error fallback:** a dashed-outline placeholder with `Icons.flag_outlined`, the ISO code,
  and a **Retry** button that re-runs the request. The quiz remains fully playable — an
  unrenderable flag is a cosmetic failure, never a crash and never a game stall.
- A dead network is additionally surfaced as a non-blocking banner rather than an exception
  dialog.

### 9.3 Responsive (phone + web)

No layout is hard-coded to a device size; one `LayoutBuilder` breakpoint switch:

| Available width | Layout |
| --------------- | ------ |
| `< 600` (phone) | Single column, 16 px padding, 1-column options, max content width = full width |
| `600–1000` (tablet / small web) | Single column, content capped at 600 px and centred |
| `> 1000` (desktop web) | Content capped at 880 px and centred; flag max width 420; options in a 2×2 grid |

Additional guarantees:

- The body is inside a `SingleChildScrollView` with `ConstrainedBox(minHeight: constraints.maxHeight)`
  and an `IntrinsicHeight` `Column`, so the layout scrolls instead of overflowing on small
  phones, in landscape, and at 200 % browser zoom.
- `MediaQuery.textScaler` is respected; option tiles use `Flexible` text with `maxLines: 2` and
  an ellipsis, so long names ("Bosnia and Herzegovina", "Trinidad and Tobago") never clip the
  tile.
- All tap targets ≥ 48 dp. Keyboard navigation and focus rings are enabled for web.
- The web build gets a proper page title and manifest name in `web/index.html` and
  `web/manifest.json`.

### 9.4 Material 3

`ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF1E88E5)))`,
plus `FilledButton`, `Card`, `Chip`, `LinearProgressIndicator`, and `ColorScheme` surface
tint tuning. Light and dark are both supported; `themeMode: ThemeMode.system`.

### 9.5 Accessibility

- `Semantics` labels on the flag ("Flag of Japan", or "Flag unavailable, retry button") and on
  every option ("Option A, Japan, not selected / correct answer / incorrect").
- Score changes are announced via `SemanticsService.announce` (through a `ViewModel` callback
  hook, so the View stays dumb).
- Colour-blind safe: state is conveyed by icon + border + text as well as hue.
- Minimum contrast ratio 4.5:1 for all option text in both themes.

---

## 10. Error Handling & Offline Behaviour

| Failure                          | Detection                             | User experience |
| -------------------------------- | ------------------------------------- | --------------- |
| No network / DNS / timeout       | `SocketException`, `TimeoutException`  | "Couldn't load countries" screen with **Retry**; static fallback list used if present |
| API 5xx or malformed JSON        | non-2xx / `FormatException`            | Same as above, with a generic message |
| API returns < 4 countries        | post-parse validation                  | `Failure` — cannot build a quiz |
| Flag image 404/timeout           | `errorBuilder` in `FlagImage`          | Per-flag fallback + Retry; question still playable |
| Answer tapped after resolution   | ViewModel guard                        | Tap ignored, no state change, no listener spam |

Rules: the data layer never throws; the ViewModel never shows a `SnackBar` or `AlertDialog`
directly (it exposes `errorMessage`, the View decides how to present it); user-initiated
taps are never left in a half-applied state.

---

## 11. Open Questions / Decisions Needed

These are the points where the latest brief is silent or conflicts with earlier instructions.
Each has a recommended default so implementation is not blocked; confirm before Phase 6 (UI).

| # | Question | Recommendation |
| - | -------- | -------------- |
| Q1 | How many questions per run? The latest brief omits it; an earlier brief said 10. | **10**, via `QuizConfig.questionCount`. |
| Q2 | Flag URL scheme is specified as `http://`. | Use **`https://`** — the http URL 301-redirects and breaks as mixed content on web (§2.2). |
| Q3 | Is a streak still tracked? Not mentioned in the latest brief, requested earlier. | **Yes**, keep as a secondary stat. Define as: correct tap → +1, wrong tap → reset. |
| Q4 | Should territories in the API list (Anguilla, Aruba, Bermuda, Puerto Rico, Hong Kong, Taiwan, Wallis & Futuna) be asked as "countries"? | **Filter them out** with a small denylist in `QuestionGenerator`/repository; keep a `strictSovereignStatesOnly` flag. Note the API has no Vatican City, Palestine, or Kosovo, so those can never be asked. |
| Q5 | Is the API the only source of truth, or should the checked-in list be primary? | **API primary, static list as offline fallback** (§8). |
| Q6 | Does a wrong tap show which option was wrong before continuing? | **Yes** — red highlight on the tapped option, remaining options stay live. This is what makes the 8/5-point ladder meaningful. |
| Q7 | Should the results screen list all 10 questions with per-question points? | **Yes**, a simple scrollable list; it is the natural payoff of the attempt system. |
| Q8 | Web-only concern: any CORS/auth proxy needed? | **No.** `access-control-allow-origin: *` verified. No proxy, no keys, nothing to configure. |

---

## 12. Implementation Phases

Each phase ends with a compiling app and a clean `flutter analyze`.

**Phase 0 — Baseline (done).** Existing `flutter create` scaffold for all platforms. Note:
`lib/data/countries.dart` and `lib/models/country.dart` were written during exploration for the
earlier hardcoded-data spec; `lib/data/countries.dart` is **kept** as the offline fallback
(§8) and `lib/models/country.dart` is **rewritten** to the §6.1 shape (adds `iso3`).
`lib/main.dart` is still the default counter demo and `test/widget_test.dart` still references
the deleted `MyApp` — both are replaced in Phase 1.

**Phase 1 — Foundation.** `core/` (config, theme, routes, `Result`), rewrite `models/`
(`country`, `question`, `answer_outcome`, `question_result`, `game_result`), `app.dart`,
`main.dart` with `MultiProvider`. Delete the counter demo; replace `test/widget_test.dart` with
a real smoke test. ✅ gate: `flutter analyze` clean, `flutter test` green.

**Phase 2 — Data layer.** `api_client`, `country_dto` (+ defensive `fromJson`),
`country_remote_data_source`, `remote_country_repository`, `static_country_repository`,
`fallback_country_repository`, `question_generator`. ✅ gate: repository tests against
`MockClient` with a captured real payload fixture; generator tests assert the four
invariants in §6.2.

**Phase 3 — ViewModel.** `load_state.dart`, `quiz_view_model.dart` with the transition table
in §7.2. ✅ gate: exhaustive unit tests over the state machine — every cell of the transition
table, points ladder (10/8/5/0), streak reset and best-streak tracking, guards rejecting taps
after resolution, `next()`/`restart()` reset behaviour. No Flutter imports in the file.

**Phase 4 — Views.** `flag_image` (loading/error/retry), `answer_option_tile`,
`attempts_indicator`, `score_header`, `feedback_banner`, `quiz_screen`, `results_screen`.
✅ gate: widget tests — startup loading → ready, answer correct on attempt 1 shows +10 and
green, two wrong taps then correct shows +5, three wrong taps reveal green and award 0,
options lock after resolution, Next advances, results screen renders, Play again resets.

**Phase 5 — Responsive + platform polish.** Breakpoint switch (§9.3), scroll-safe layout,
`web/index.html` title/manifest, Android `INTERNET` permission in the **main** manifest
(only the debug/profile manifests have it, so release builds would silently fail to load
flags), iOS ATS is already fine (HTTPS only), accessibility semantics.

**Phase 6 — Final gate.** `flutter pub get`, `flutter analyze` (zero issues, `flutter_lints`),
`flutter test`, `flutter build web`, `flutter build apk --debug`. Verify the app against a real
device and `flutter run -d chrome`.

---

## 13. Testing Strategy

| Layer | Tool | Coverage |
| ----- | ---- | -------- |
| Model | `flutter_test` | `Country.flagUrl` correctness, value equality |
| Data | `flutter_test` + `http`'s `MockClient` | 200 parse, envelope shape, missing `iso2` skipped, 500 → `Failure`, timeout → `Failure`, malformed JSON → `Failure`, fallback repository kicks in on failure |
| Generator | `flutter_test` | option count/uniqueness/index range, correct answer present, position distribution over 200 runs, no repeated question within a run |
| ViewModel | `flutter_test` (no widgets) | full transition table, points ladder, streak, score accumulation, guards, `restart()` |
| Widget | `flutter_test` | per Phase 4 gates; uses `MockClient` so no network in tests |
| Manual | device + `flutter run -d chrome` | real flag load, offline behaviour, responsive breakpoints, dark mode |

Network is **never** touched in tests. `Image.network` inside widget tests resolves through
`errorBuilder` under the test `HttpClient` (which always returns 400), which is itself a useful
assertion that the error fallback renders without throwing.

---

## 14. Risks & Mitigations

| Risk | Impact | Mitigation |
| ---- | ------ | ---------- |
| `countriesnow.space` is a free public API — could rate-limit, change shape, or disappear | App cannot start | Static fallback list (already in repo); tolerant parser; clear error screen with retry |
| API 222-country list contains territories | Ambiguous questions | Denylist filter (Q4) |
| Upstream key casing changes (`iso2` → `Iso2`, as seen in the sibling `/iso` endpoint) | Silent 0-country parse | Tolerant mapper + a unit test pinned to the observed real payload |
| `package:http` without `dio` means hand-rolled error mapping | Boilerplate, possible misses | Single `ApiClient` choke point; exhaustive `Failure` mapping unit-tested |
| `ChangeNotifier` on a large state object causes broad rebuilds | Jank on web | `context.select` for the score/streak chips; flag image isolated behind `AnimatedSwitcher` |
| Web mixed content if `http://` flag URLs are used | Broken flags on web | HTTPS constant (§2.2) |
| Release Android build has no `INTERNET` permission | Flags fail in release only | Phase 5 manifest fix + release-build smoke test |
| No `dart:io` on web | Compile errors if used directly | HTTP isolated in `data/` behind `package:http`; enforced by the dependency rule in §4 |

---

## 15. Definition of Done

- [ ] 10-question run; flag + 4 country options; correct option identifiable.
- [ ] Correct tap awards 10 / 8 / 5 for the 1st / 2nd / 3rd attempt.
- [ ] Three failed attempts reveal the correct option and award 0.
- [ ] Wrong taps give instant red feedback; correct taps give instant green feedback.
- [ ] Score, streak, and best streak tracked and displayed.
- [ ] **Next** advances; final score screen after the last question; **Play again** resets.
- [ ] Country names from `countriesnow.space`; flags from `flagcdn.com/w320/{iso2}.png`.
- [ ] Flag loading indicator, error fallback, and retry.
- [ ] MVVM layering respected; `provider` ViewModels; no business logic in widgets.
- [ ] Material 3, light + dark, no layout overflow on small phone / landscape / desktop web.
- [ ] Works on Android, iOS, and web.
- [ ] `flutter analyze` reports zero issues; `flutter test` green.
