# Azure DevOps — mentions

How the reserved `@[userRef]` token in markdown bodies projects to AzDO's mention syntax.

## Token shape

In canonical markdown, mentions appear as:

```
@[<userRef>]
```

where `<userRef>` is the opaque handle returned by `resolveUser({ email })` or `resolveUser({ name })`. Internally on the AzDO side, the handle is an identity descriptor object containing `displayName`, `uniqueName` (UPN), and `descriptor`.

## Rendered HTML

The adapter emits:

```html
<a href="#" data-vss-mention="version:2.0,<uniqueName>">@<displayName></a>
```

The `data-vss-mention` attribute is the magic value AzDO recognizes. Both `version:2.0` and the unique name are required. The `@<displayName>` text is the visible part.

The `href="#"` is a placeholder — AzDO renders the mention as an interactive chip regardless. Do not change the `href` value or AzDO will treat the mention as a plain link.

## Examples

`@[taha@example.com-descriptor]` →

```html
<a href="#" data-vss-mention="version:2.0,taha@example.com">@Taha Bikanerwala</a>
```

## Resolution failure fallback

If `resolveUser` returned a "resolved by name only, no descriptor" handle (the user wasn't found in AzDO):

- Emit the plain text `@<displayName>` instead.
- Surface a warning: `Could not resolve <name> to an AzDO identity; mention rendered as plain text.`

The agent should not retry. The caller may decide to skip the mention or substitute a fallback contact.

## Mention placement rules

- **Comments** (`addComment`): mentions trigger a notification. Use sparingly.
- **Description** (`updateFields(body: ...)`): mentions are rendered but do not always notify (AzDO behavior varies by org policy). Do not rely on a description mention to page someone.
- **Title** (`updateFields(title: ...)`): mentions are stripped. The adapter removes them before writing.
- **Tags / labels**: mentions are not supported. Strip them.

## Multiple mentions

Multiple `@[userRef]` tokens in the same body are all converted independently. No deduplication — if the body says the same person three times, three mention chips render.

## Round-trip from existing HTML

When `getIssue` reads a description that already contains AzDO mentions, the adapter parses each `<a href="..." data-vss-mention="...">@Name</a>` element and emits `@[userRef]` if `resolveUser({ uniqueName })` succeeds. If the lookup fails (deactivated user, deleted account), emit the plain text `@Name` and surface a one-line warning.
