# https://github.com/fenollp/mediapipe-desktop-linux-demos

Cf. https://google.github.io/mediapipe/solutions/solutions.html

Requires docker >=18.06

```
# make help
make run.face_detection_cpu
make run.face_detection_gpu
make run.face_mesh_cpu
make run.face_mesh_gpu
make run.hair_segmentation_cpu
make run.hair_segmentation_gpu
make run.hand_tracking_cpu
make run.hand_tracking_gpu
make run.holistic_tracking_cpu
make run.holistic_tracking_gpu
make run.iris_tracking_cpu
make run.iris_tracking_gpu
make run.object_detection_cpu
make run.object_detection_gpu
make run.object_tracking_cpu
make run.object_tracking_gpu
make run.pose_tracking_cpu
make run.pose_tracking_gpu
make run.selfie_segmentation_cpu
make run.selfie_segmentation_gpu
```

Linux-only.

Builds & fetches all artifacts required before running the given [mediapipe](https://github.com/google/mediapipe) example.

You can safely `export DOCKER_HOST=ssh://a-big-machine` to build things faster.
