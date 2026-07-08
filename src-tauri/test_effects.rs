use tauri::window::{Effect, EffectState, EffectsBuilder};
fn test() {
    let _effects = EffectsBuilder::new()
        .effect(Effect::Popover)
        .state(EffectState::Active)
        .build();
}
