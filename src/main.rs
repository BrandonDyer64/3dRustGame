pub mod camera;
pub mod vector;

pub use camera::Camera;
use luminance::blending::{Equation, Factor};
use luminance::context::GraphicsContext as _;
use luminance::framebuffer::Framebuffer;
use luminance::pixel::RGBA32F;
use luminance::render_state::RenderState;
use luminance::shader::program::Program;
use luminance::tess::{Mode, TessBuilder};
use luminance::texture::{Dim2, Flat};
use luminance_glfw::{
    Action, CursorMode, GlfwSurface, Key, Surface, WindowDim, WindowEvent, WindowOpt,
};
use std::time::Instant;
pub use vector::Vector3;

const VS: &'static str = include_str!("shader.vert.glsl");
const FS: &'static str = include_str!("shader.frag.glsl");
const POST_FS: &'static str = include_str!("post.frag.glsl");

fn main() {
    let mut surface = GlfwSurface::new(
        WindowDim::Windowed(1280, 1280),
        "Hello, world!",
        WindowOpt::default().set_cursor_mode(CursorMode::Invisible),
    )
    .expect("GLFW surface creation");

    let program = Program::<(), (), ()>::from_strings(None, VS, None, FS)
        .expect("program creation")
        .ignore_warnings();

    let post_program = Program::<(), (), ()>::from_strings(None, VS, None, POST_FS)
        .expect("program creation")
        .ignore_warnings();

    let tess = TessBuilder::new(&mut surface)
        .set_vertex_nb(4)
        .set_mode(Mode::TriangleFan)
        .build()
        .unwrap();

    let mut back_buffer = surface.back_buffer().unwrap();
    let size = surface.size();
    let mut history_buffer_1 = Framebuffer::<Flat, Dim2, RGBA32F, ()>::new(&mut surface, size, 0)
        .expect("framebuffer creation");
    let mut history_buffer_2 = Framebuffer::<Flat, Dim2, RGBA32F, ()>::new(&mut surface, size, 0)
        .expect("framebuffer creation");
    let render_state =
        RenderState::default().set_blending((Equation::Additive, Factor::SrcAlpha, Factor::Zero));

    let time_start = Instant::now();
    let mut time_last = time_start;

    let mut camera = Camera {
        pos: Vector3 {
            x: -3.,
            y: 5.,
            z: 0.,
        },
        dir: Vector3 {
            x: 0.,
            y: -1.,
            z: 0.,
        },
    };

    let mut frame_num = 0;

    let mut forward = 0.;
    let mut right = 0.;

    let speed = 8.;

    'app: loop {
        frame_num += 1;
        let mut resize = false;
        let time_now = Instant::now();
        let time_elapsed = (time_now - time_start).as_micros() as f64 / 1_000_000f64;
        let time_delta = (time_now - time_last).as_micros() as f64 / 1_000_000f64;
        time_last = time_now;
        let camera_prev = camera.clone();

        let fps = 1f64 / time_delta;
        println!("FPS: {}", fps as i32);

        for event in surface.poll_events() {
            match event {
                WindowEvent::Close => break 'app,
                WindowEvent::Key(Key::Escape, _, Action::Release, _) => break 'app,
                WindowEvent::Key(key, _, action, _)
                    if action == Action::Press || action == Action::Release =>
                {
                    let d = match key {
                        Key::A => (1., 0.),
                        Key::D => (-1., 0.),
                        Key::W => (0., 1.),
                        Key::S => (0., -1.),
                        _ => (0., 0.),
                    };
                    if action == Action::Press {
                        forward += d.1;
                        right += d.0;
                    } else {
                        forward -= d.1;
                        right -= d.0;
                    }
                }
                WindowEvent::FramebufferSize(..) => resize = true,
                WindowEvent::CursorPos(x, y) => {
                    camera.dir.x = (-x as f32 * 0.01).cos();
                    camera.dir.y = (-x as f32 * 0.01).sin();
                    camera.dir.z = (-y as f32 * 0.01) + 2.;
                }
                _ => (),
            }
        }

        camera.pos.y += camera.dir.y * time_delta as f32 * forward * speed;
        camera.pos.x += camera.dir.x * time_delta as f32 * forward * speed;
        camera.pos.z += camera.dir.z * time_delta as f32 * forward * speed;
        camera.pos.y += camera.dir.x * time_delta as f32 * right * speed;
        camera.pos.x += -camera.dir.y * time_delta as f32 * right * speed;

        let size = surface.size();

        if resize {
            back_buffer = surface.back_buffer().unwrap();
            history_buffer_1 =
                Framebuffer::new(&mut surface, size, 0).expect("framebuffer recreation");
            history_buffer_2 =
                Framebuffer::new(&mut surface, size, 0).expect("framebuffer recreation");
        }

        let mut builder = surface.pipeline_builder();

        let (front, back) = if frame_num % 2 == 0 {
            (&history_buffer_1, &history_buffer_2)
        } else {
            (&history_buffer_2, &history_buffer_1)
        };

        builder.pipeline(back, [0., 0., 0., 0.], |pipeline, mut shd_gate| {
            let bound_texture = pipeline.bind_texture(front.color_slot());

            shd_gate.shade(&program, |iface, mut rdr_gate| {
                let query = iface.query();

                if let Ok(u) = query.ask("time") {
                    u.update(time_elapsed as f32);
                }

                if let Ok(u) = query.ask("delta") {
                    u.update(time_delta as f32);
                }

                if let Ok(u) = query.ask("cam_pos") {
                    u.update([camera.pos.x, camera.pos.y, camera.pos.z]);
                }

                if let Ok(u) = query.ask("cam_dir") {
                    u.update([camera.dir.x, camera.dir.y, camera.dir.z]);
                }

                if let Ok(u) = query.ask("cam_prev_pos") {
                    u.update([camera_prev.pos.x, camera_prev.pos.y, camera_prev.pos.z]);
                }

                if let Ok(u) = query.ask("cam_prev_dir") {
                    u.update([camera_prev.dir.x, camera_prev.dir.y, camera_prev.dir.z]);
                }

                if let Ok(u) = query.ask("history") {
                    u.update(&bound_texture);
                }

                if let Ok(u) = query.ask("iResolution") {
                    u.update([size[0] as f32, size[1] as f32]);
                }

                rdr_gate.render(render_state, |mut tess_gate| {
                    tess_gate.render(&tess);
                });
            });
        });

        builder.pipeline(&back_buffer, [0., 0., 0., 0.], |pipeline, mut shd_gate| {
            let bound_texture = pipeline.bind_texture(back.color_slot());
            shd_gate.shade(&post_program, |iface, mut rdr_gate| {
                let query = iface.query();
                if let Ok(u_frame) = query.ask("frame") {
                    u_frame.update(&bound_texture);
                }
                rdr_gate.render(render_state, |mut tess_gate| {
                    tess_gate.render(&tess);
                })
            })
        });

        surface.swap_buffers();
    }
}
