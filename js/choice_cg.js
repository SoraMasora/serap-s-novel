// One reply frame after a dialogue choice. Original story and stage stay intact.
const ChoiceCG = (() => {
  const catalog = {
  "c1_store_sorry": "cg_c1_store_sorry",
  "c1_store_rude": "cg_c1_store_rude",
  "c1_bug_yes": "cg_c1_bug_yes",
  "c1_bug_no": "cg_c1_bug_no",
  "c1_room_good": "cg_c1_room_good",
  "c1_room_mid": "cg_c1_room_mid",
  "c1_room_bad": "cg_c1_room_bad",
  "c1_shift_dodge": "cg_c1_shift_dodge",
  "c1_shift_sorry": "cg_c1_shift_sorry",
  "c1_shift_none": "cg_c1_shift_none",
  "c1_cafe_good": "cg_c1_cafe_good",
  "c1_cafe_bad": "cg_c1_cafe_bad",
  "c1_roof1_bad": "cg_c1_roof1_bad",
  "c1_study_good": "cg_c1_study_good",
  "c1_study_bad": "cg_c1_study_bad",
  "c1_guests_push": "cg_c1_guests_push",
  "c1_pastor_defend": "cg_c1_pastor_defend",
  "c1_pastor_stay": "cg_c1_pastor_stay",
  "c1_pastor_betray": "cg_c1_pastor_betray",
  "c1_roof_silent": "cg_c1_roof_silent",
  "c1_hand": "cg_c1_hand",
  "c1_hand_ok": "cg_c1_hand_ok",
  "c1_hug": "cg_c1_hug",
  "c1_hug_ok": "cg_c1_hug_ok",
  "store_2a": "cg_store_2a",
  "store_2b": "cg_store_2b",
  "eve1_e1": "cg_eve1_e1",
  "eve2_study_a": "cg_eve2_study_a",
  "eve2_study_b": "cg_eve2_study_b",
  "eve2_song_ask": "cg_eve2_song_ask",
  "eve2_end": "cg_eve2_end",
  "eve3_expo_a": "cg_eve3_expo_a",
  "eve3_expo_b": "cg_eve3_expo_b",
  "ch3_therapy": "cg_ch3_therapy",
  "c3_smoke_no": "cg_c3_smoke_no",
  "c3_smoke": "cg_c3_smoke",
  "c3_bal_quiet": "cg_c3_bal_quiet",
  "c3_calm_a": "cg_c3_calm_a",
  "c3_calm_b": "cg_c3_calm_b",
  "c3_calm_read": "cg_c3_calm_read",
  "c3_calm_block": "cg_c3_calm_block",
  "c3_calm_light": "cg_c3_calm_light",
  "c3_eve_soft": "cg_c3_eve_soft",
  "c3_eve_push": "cg_c3_eve_push",
  "c3_eve_conf": "cg_c3_eve_conf",
  "c3_eve_quiet": "cg_c3_eve_quiet",
  "c3_eve_lie": "cg_c3_eve_lie",
  "c3_eve_admit": "cg_c3_eve_admit",
  "c3_q_hard": "cg_c3_q_hard",
  "c3_pl_ask": "cg_c3_pl_ask",
  "c3_pl_grab": "cg_c3_pl_grab",
  "c3_panic_break": "cg_c3_panic_break",
  "m2_door_call": "cg_m2_door_call",
  "m2_door_quiet": "cg_m2_door_quiet",
  "m2_roof_a": "cg_m2_roof_a",
  "m2_roof_b": "cg_m2_roof_b",
  "m2_roof_b_ns": "cg_m2_roof_b_ns",
  "m2_roof_c": "cg_m2_roof_c",
  "m2_palm_a": "cg_m2_palm_a",
  "m2_palm_b": "cg_m2_palm_b",
  "m2_shift_a": "cg_m2_shift_a",
  "m2_shift_b": "cg_m2_shift_b",
  "m2_portrait_a": "cg_m2_portrait_a",
  "m2_portrait_b": "cg_m2_portrait_b",
  "m2_snow_words": "cg_m2_snow_words",
  "m2_snow_joke": "cg_m2_snow_joke",
  "m2_cold_absent_k": "cg_m2_cold_absent_k"
};
  let pending = false, key = '', restoreNext = '';
  const layer = () => document.getElementById('choiceCGFrame');
  return {
    arm() { pending = true; },
    clear() { key = ''; layer().classList.add('hidden'); },
    reset() { this.clear(); pending = false; restoreNext = ''; },
    restore(value) { restoreNext = value || ''; },
    key() { return key; },
    response(scene) {
      key = restoreNext || (pending ? catalog[scene] || '' : '');
      pending = false; restoreNext = '';
      const src = key && ASSETS.bg[key];
      layer().style.backgroundImage = src ? `url("${src}")` : '';
      layer().classList.toggle('hidden', !src);
      return key;
    }
  };
})();
