use luminance::blending::{Equation, Factor};
use luminance::context::GraphicsContext as _;
use luminance::render_state::RenderState;
use luminance::shader::program::Program;
use luminance::tess::{Mode, TessBuilder};
use luminance_derive::UniformInterface;
use luminance_glfw::{Action, GlfwSurface, Key, Surface, WindowDim, WindowEvent, WindowOpt};

const VS: &'static str = include_str!("shader.vert.glsl");
const FS: &'static str = include_str!("shader.frag.glsl");

#[derive(UniformInterface)]
struct ShaderInterface {}

fn main() {
    let mut surface = GlfwSurface::new(
        WindowDim::Windowed(1280, 720),
        "Hello, world!",
        WindowOpt::default(),
    )
    .expect("GLFW surface creation");

    let program = Program::<(), (), ShaderInterface>::from_strings(None, VS, None, FS)
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

    'app: loop {
        let mut resize = false;

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
                shd_gate.shade(&program, |_iface, mut rdr_gate| {
                    rdr_gate.render(render_state, |mut tess_gate| {
                        tess_gate.render(&tess);
                    });
                });
            },
        );

        surface.swap_buffers();
    }
}
