group "default" {
  targets = [
    "libs",
    "face_detection_cpu",
  ]
}

target "dockerfile" {
  dockerfile = "Dockerfile"
  args = {
    "MEDIAPIPE_COMMIT" = "e6c19885c6d3c6f410c730952aeed2852790d306"
  }
}

target "libs" {
  inherits = ["dockerfile"]
  target = "libs"
  output = ["./lib/"]
}

group "bins" {
  targets = [
    "libs",
    "selfie_segmentation_cpu",
    "object_detection_cpu",
    "holistic_tracking_gpu",
    "hair_segmentation_gpu",
    "holistic_tracking_cpu",
    "object_detection_gpu",
    "selfie_segmentation_gpu",
    "iris_tracking_gpu",
    "pose_tracking_gpu",
    "hair_segmentation_cpu",
    "face_detection_cpu",
    "face_mesh_cpu",
    "hand_tracking_gpu",
    "object_tracking_cpu",
    "object_tracking_gpu",
    "iris_tracking_cpu",
    "pose_tracking_cpu",
    "face_detection_gpu",
    "face_mesh_gpu",
    "hand_tracking_cpu",
  ]
}

target "selfie_segmentation_cpu" {
  inherits = ["dockerfile"]
  target = "selfie_segmentation_cpu"
  output = ["./bin/"]
}
target "object_detection_cpu" {
  inherits = ["dockerfile"]
  target = "object_detection_cpu"
  output = ["./bin/"]
}
target "holistic_tracking_gpu" {
  inherits = ["dockerfile"]
  target = "holistic_tracking_gpu"
  output = ["./bin/"]
}
target "hair_segmentation_gpu" {
  inherits = ["dockerfile"]
  target = "hair_segmentation_gpu"
  output = ["./bin/"]
}
target "holistic_tracking_cpu" {
  inherits = ["dockerfile"]
  target = "holistic_tracking_cpu"
  output = ["./bin/"]
}
target "object_detection_gpu" {
  inherits = ["dockerfile"]
  target = "object_detection_gpu"
  output = ["./bin/"]
}
target "selfie_segmentation_gpu" {
  inherits = ["dockerfile"]
  target = "selfie_segmentation_gpu"
  output = ["./bin/"]
}
target "iris_tracking_gpu" {
  inherits = ["dockerfile"]
  target = "iris_tracking_gpu"
  output = ["./bin/"]
}
target "pose_tracking_gpu" {
  inherits = ["dockerfile"]
  target = "pose_tracking_gpu"
  output = ["./bin/"]
}
target "hair_segmentation_cpu" {
  inherits = ["dockerfile"]
  target = "hair_segmentation_cpu"
  output = ["./bin/"]
}
target "face_detection_cpu" {
  inherits = ["dockerfile"]
  target = "face_detection_cpu"
  output = ["./bin/"]
}
target "face_mesh_cpu" {
  inherits = ["dockerfile"]
  target = "face_mesh_cpu"
  output = ["./bin/"]
}
target "hand_tracking_gpu" {
  inherits = ["dockerfile"]
  target = "hand_tracking_gpu"
  output = ["./bin/"]
}
target "object_tracking_cpu" {
  inherits = ["dockerfile"]
  target = "object_tracking_cpu"
  output = ["./bin/"]
}
target "object_tracking_gpu" {
  inherits = ["dockerfile"]
  target = "object_tracking_gpu"
  output = ["./bin/"]
}
target "iris_tracking_cpu" {
  inherits = ["dockerfile"]
  target = "iris_tracking_cpu"
  output = ["./bin/"]
}
target "pose_tracking_cpu" {
  inherits = ["dockerfile"]
  target = "pose_tracking_cpu"
  output = ["./bin/"]
}
target "face_detection_gpu" {
  inherits = ["dockerfile"]
  target = "face_detection_gpu"
  output = ["./bin/"]
}
target "face_mesh_gpu" {
  inherits = ["dockerfile"]
  target = "face_mesh_gpu"
  output = ["./bin/"]
}
target "hand_tracking_cpu" {
  inherits = ["dockerfile"]
  target = "hand_tracking_cpu"
  output = ["./bin/"]
}
