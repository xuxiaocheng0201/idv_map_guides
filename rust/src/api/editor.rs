use std::collections::HashMap;

use crate::api::map::Structure;

#[flutter_rust_bridge::frb(dart_async)]
pub fn load_structures(content: &[u8]) -> anyhow::Result<HashMap<String, Structure>> {
    let structures = serde_json::from_slice::<HashMap<String, map_core::core::data::Structure>>(content)?;
    Ok(structures.into_iter().map(|(k, v)| (k, v.into())).collect())
}

#[flutter_rust_bridge::frb(dart_async)]
pub fn save_structures(structures: HashMap<String, Structure>) -> anyhow::Result<Vec<u8>> {
    let structures = structures.into_iter().map(|(k, v)| (k, v.into())).collect();
    serde_json::to_vec::<HashMap<String, map_core::core::data::Structure>>(&structures).map_err(Into::into)
}
