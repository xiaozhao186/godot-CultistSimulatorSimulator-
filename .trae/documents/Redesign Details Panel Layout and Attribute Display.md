I will redesign the `DetailsPanel` to match the new requirements.

**1. Scene Refactoring (`scenes/DetailsPanel.tscn`)**

*   **Structure Update**:
    *   **Root Panel**: Resize to a rectangular shape (e.g., `500x300`). Use `res://pic/cardlay.png` as the background (via StyleBoxTexture).
    *   **Close Button**: Position at Top-Left (`10, 10`).
    *   **Title Label**: Position at Top-Left, below or next to the close button (e.g., `50, 10` or `10, 50`).
    *   **Image Rect**: Position at Top-Right (e.g., anchor `Top-Right`, offset `(-110, 10)` to `(-10, 110)`). Size `100x100`.
    *   **Description Label**: Position at Left-Middle, below Title. Width extending to the Image.
    *   **Attributes Container**: New `HBoxContainer` at the Bottom area. Layout direction: Right-to-Left (or Left-to-Right starting from right? User said "starting from right"). I will use `BoxContainer` with `alignment = END` (Right).

**2. Script Logic Update (`scripts/DetailsPanel.gd`)**

*   **Attribute Visualization**:
    *   Remove the old text-based attribute list code.
    *   Create a method `_populate_attributes(token)`.
    *   Iterate through `token.data.tags` and `token.data.attributes`.
    *   For each attribute/tag:
        *   Instantiate a new `TextureRect` (Icon).
        *   Texture: `res://pic/icon.jpg` (User specified this as the generic icon).
        *   If it's a numeric attribute (from `token.data.attributes`), add a `Label` next to it (child of a HBox container wrapping the icon?).
        *   **Tooltip**: Set `tooltip_text` on the Icon to show the specific info (e.g., "Tag: Fire" or "Attack: 5").
    *   **Layout**: Add these icons to the `AttributesContainer`.

**3. Assets**

*   Use `res://pic/cardlay.png` for background.
*   Use `res://pic/icon.jpg` for attribute icons.

**4. Implementation Steps**

1.  **Modify `DetailsPanel.tscn`**: Reconstruct the scene tree and layout.
2.  **Modify `DetailsPanel.gd`**: Update the logic to populate the new UI elements.

**Details for Attribute Icon Implementation:**
*   Since I can't easily create a separate scene for the attribute icon without `Write` (which is fine, but inline generation is faster for simple things), I'll generate the nodes via code in `DetailsPanel.gd`.
*   Structure for each attribute: `HBoxContainer` (Icon + Label).
*   The main container will be an `HBoxContainer` at the bottom of the panel, right-aligned.

**Refined Plan:**
1.  **Edit `DetailsPanel.tscn`**:
    *   Change root to `Panel`.
    *   Add `StyleBoxTexture` to root with `cardlay.png`.
    *   Reposition `Title`, `CloseButton`, `Desc`, `Icon` (Card Image).
    *   Add `HBoxContainer` named `AttributesContainer` at the bottom.
2.  **Edit `DetailsPanel.gd`**:
    *   Update `_on_token_clicked`.
    *   Clear `AttributesContainer` children.
    *   Loop tags: Create Icon -> Set Tooltip -> Add to Container.
    *   Loop attributes: Create Icon -> Set Tooltip -> Create Label (Value) -> Add both to a mini-HBox -> Add to Main Container.

**Asset Check**:
*   `d:\Program Files (x86)\Godot_v4.5.1\box\ppd-1\pic\cardlay.png`
*   `d:\Program Files (x86)\Godot_v4.5.1\box\ppd-1\pic\icon.jpg`
*   Both exist (User provided paths). I will assume they are imported as resources.

Let's go.