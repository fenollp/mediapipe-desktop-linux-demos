group "default" {
  targets = [
    "libs",
    "face_detection_cpu",
  ]
}

target "dockerfile" {
  dockerfile = "Dockerfile"
  args = {
    "MEDIAPIPE_COMMIT" = "MEDIAPIPE_COMMIT_value"
  }
}

target "libs" {
  inherits = ["dockerfile"]
  target = "libs"
  output = ["./lib/"]
}
