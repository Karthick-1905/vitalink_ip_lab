# VitaLink UML Pack

This folder contains editable PlantUML source files for the main UML views of the VitaLink project.

## Included diagrams

- `use_case.puml`: patient, doctor, and admin capabilities
- `component_architecture.puml`: frontend, backend, storage, realtime, and ML separation
- `deployment.puml`: EC2, Nginx, blue-green backend containers, MongoDB, Filebase
- `domain_class_model.puml`: main persistent domain objects
- `patient_report_sequence.puml`: patient INR submission flow
- `doctor_update_sequence.puml`: doctor update to patient notification flow
- `patient_activity.puml`: patient operational activity flow
- `doctor_activity.puml`: doctor operational activity flow
- `admin_activity.puml`: admin governance activity flow
- `notification_state.puml`: notification lifecycle

## Rendering

If `plantuml` is installed locally:

```bash
python3 docs/uml/render_uml.py
```

If PlantUML is not installed, you can also render with Docker:

```bash
docker run --rm -v "$PWD/docs/uml:/workspace" plantuml/plantuml -tpng /workspace/*.puml
```

## Output

Rendered PNG files are written next to the `.puml` files.

## Scope note

This UML pack reflects the current repository structure.

Important boundary:

- the `ml_pipeline` is modeled as an offline/research subsystem
- it is not shown as an active runtime dependency of the live Express backend because the current codebase does not integrate it into request handling
