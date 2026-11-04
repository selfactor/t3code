declare const __T3CODE_BUILD_VARIANT__: string | undefined;

/**
 * Baked in at bundle time from T3CODE_DESKTOP_VARIANT. "lab" is a locally built fork
 * (T3 Lab) that installs beside T3 Code: its own name, profile and state folder, and
 * no update feed, because a local build job replaces it.
 */
export const isLabBuild =
  typeof __T3CODE_BUILD_VARIANT__ !== "undefined" && __T3CODE_BUILD_VARIANT__ === "lab";
