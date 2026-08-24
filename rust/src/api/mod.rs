pub mod map;
pub mod editor;

#[flutter_rust_bridge::frb(init)]
pub fn initialize() {
    flutter_rust_bridge::setup_default_user_utils();
}
