use luminance::blending::{Equation, Factor};
use luminance::context::GraphicsContext as _;
use luminance::render_state::RenderState;
use luminance::shader::program::Program;
use luminance::tess::{Mode, TessBuilder};
use luminance_glfw::{Action, GlfwSurface, Key, Surface, WindowDim, WindowEvent, WindowOpt};
use std::time::Instant;

const VS: &'static str = include_str!("shader.vert.glsl");
const FS: &'static str = include_str!("shader.frag.glsl");

fn main() {
    let mut surface = GlfwSurface::new(
        WindowDim::Windowed(720, 720),
        "Hello, world!",
        WindowOpt::default(),
    )
    .expect("GLFW surface creation");

    let program = Program::<(), (), ()>::from_strings(None, VS, None, FS)
        .expect("program creation")
        .ignore_warnings();

    let tess = TessBuilder::new(&mut surface)
        .set_vertex_nb(4)
        .set_mode(Mode::TriangleFan)
        .build()
        .unwrap();

    let mut back_buffer = surface.back_buffer().unwrap();
    let render_state =
        RenderState::default().set_blending((Equation::Additive, Factor::SrcAlpha, Factor::Zero));

    let time_start = Instant::now();
    let mut time_last = time_start;

    'app: loop {
        let mut resize = false;
        let time_now = Instant::now();
        let time_elapsed = (time_now - time_start).as_micros() as f64 / 1_000_000f64;
        let time_delta = (time_now - time_last).as_micros() as f64 / 1_000_000f64;
        time_last = time_now;

        let fps = 1f64 / time_delta;
        println!("FPS: {}", fps as i32);

        for event in surface.poll_events() {
            match event {
                WindowEvent::Close => break 'app,
                WindowEvent::Key(Key::Escape, _, Action::Release, _) => break 'app,
                WindowEvent::FramebufferSize(..) => resize = true,
                _ => (),
            }
        }

        if resize {
            back_buffer = surface.back_buffer().unwrap();
        }

        surface.pipeline_builder().pipeline(
            &back_buffer,
            [0., 0., 0., 0.],
            |_pipeline, mut shd_gate| {
                shd_gate.shade(&program, |iface, mut rdr_gate| {
                    let query = iface.query();

                    if let Ok(u_time) = query.ask("time") {
                        u_time.update(time_elapsed as f32);
                    }

                    if let Ok(u_delta) = query.ask("delta") {
                        u_delta.update(time_delta as f32);
                    }

                    rdr_gate.render(render_state, |mut tess_gate| {
                        tess_gate.render(&tess);
                    });
                });
            },
        );

        surface.swap_buffers();
    }
}
