import opengl, windy

var window = newWindow("Mandelbrot", ivec2(800, 800))
window.makeContextCurrent()
loadExtensions()

var vertexSource = """
#version 330

layout (location = 0) in vec2 pos;

void main() {
    gl_Position = vec4(pos, 0.0, 1.0);
}
"""

var fragmentSource = """
#version 430

uniform dvec2 resolution;

uniform dvec2 zCenter;
uniform double zSize;

uniform int iterations;

out vec4 fragColor;

vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    float tau = 6.28318;

    return a + b * cos(tau * (c * t + d));
}

// 2 + 3i
// (2 + 3i)(2 + 3i)
// 4 + 6i + 6i + 9i^2
// 4 + 12i + 9(-1)
// 4 - 9 + 12i
// -5 + 12i
dvec2 f(dvec2 z, dvec2 c) {
    double r = z.x * z.x - z.y * z.y;
    double i = z.x * z.y + z.x * z.y;

    dvec2 squared = dvec2(r, i);
    return squared + c;
}

void main() {
    dvec2 uv = dvec2(gl_FragCoord.xy) / resolution;
    // center + (uv converted to -2 .. 2) * (zoom factor (smaller is more zoomed in) / 4)
    dvec2 c = zCenter + (uv * 4.0 - dvec2(2.0)) * (zSize / 4.0);

    dvec2 z = dvec2(0.0, 0.0);
    bool escaped = false;
    int passed;

    int i = 0;
    while (i < iterations) {
        z = f(z, c);

        passed = i;

        if (length(z) > 2.0) {
            escaped = true;
            break;
        }

        i++;
    }

    vec3 a = vec3(1.0, 0.0, 0.0);
    vec3 b = vec3(0.59, 0.55, 0.75);
    vec3 pc = vec3(0.1, 0.2, 0.3);
    vec3 d = vec3(0.75);

    fragColor = escaped ? vec4(palette(float(iterations - passed) / float(iterations), a, b, pc, d), 1.0) : vec4(vec3(0.0), 1.0);
}
"""

var vertex = glCreateShader(GL_VERTEX_SHADER)
var fragment = glCreateShader(GL_FRAGMENT_SHADER)

glShaderSource(vertex, 1, allocCStringArray([vertexSource]), nil)
glShaderSource(fragment, 1, allocCStringArray([fragmentSource]), nil)

glCompileShader(vertex)
glCompileShader(fragment)

var compiled: int32
glGetShaderiv(vertex, GL_COMPILE_STATUS, addr compiled)

if compiled != 1:
    var length: int32
    glGetShaderiv(vertex, GL_INFO_LOG_LENGTH, addr length)

    var cstr = cast[cstring](alloc(length + 1))
    glGetShaderInfoLog(vertex, length, nil, cstr)

    echo "vertex shader failed: ", $cstr

    dealloc(cstr)

glGetShaderiv(fragment, GL_COMPILE_STATUS, addr compiled)

if compiled != 1:
    var length: int32
    glGetShaderiv(fragment, GL_INFO_LOG_LENGTH, addr length)

    var cstr = cast[cstring](alloc(length + 1))
    glGetShaderInfoLog(fragment, length, nil, cstr)

    echo "fragment shader failed: ", $cstr

    dealloc(cstr)

var program = glCreateProgram()

glAttachShader(program, vertex)
glAttachShader(program, fragment)

glLinkProgram(program)

glUseProgram(program)

proc l(name: string): int32 =
    return glGetUniformLocation(program, cstring(name))

glUniform2d(l("resolution"), window.size.x.float64, window.size.y.float64)

var data: array[6 * 2, float32] = [
    -1f, -1f,
    1f, -1f,
    -1f, 1f,

    -1f, 1f,
    1f, 1f,
    1f, -1f,
]

var vertexBuffer: uint32
glGenBuffers(1, addr vertexBuffer)

var vertexArray: uint32
glGenVertexArrays(1, addr vertexArray)

glBindVertexArray(vertexArray)

glBindBuffer(GL_ARRAY_BUFFER, vertex)
glBufferData(GL_ARRAY_BUFFER, sizeof(float32) * 2 * 6, addr data[0], GL_STATIC_DRAW)

glVertexAttribPointer(0, 2, cGL_FLOAT, false, 0, nil)
glEnableVertexAttribArray(0)

var zCenter = dvec2()
var zSize: float64 = 3f
var iterations: int32 = 1000

proc input =
    let movementFactor = 0.01f

    if window.buttonDown[KeyA]:
        zCenter.x -= zSize * movementFactor
    if window.buttonDown[KeyD]:
        zCenter.x += zSize * movementFactor
    if window.buttonDown[KeyW]:
        zCenter.y += zSize * movementFactor
    if window.buttonDown[KeyS]:
        zCenter.y -= zSize * movementFactor

    if window.buttonDown[KeyMinus]:
        if iterations > 50:
            iterations = (iterations * 99) div 100
    
    if window.buttonDown[KeyEqual]:
        if iterations < 10000:
            iterations = (iterations * 101) div 100

    zSize *= 1f - window.scrollDelta.y * 0.1f

window.onFrame = proc =
    glClearColor(0f, 0f, 0f, 0f)
    glClear(GL_COLOR_BUFFER_BIT)

    glUniform2d(l("zCenter"), zCenter.x, zCenter.y)
    glUniform1d(l("zSize"), zSize)
    glUniform1i(l("iterations"), iterations)

    glDrawArrays(GL_TRIANGLES, 0, 6)

while not window.closeRequested:
    input()

    window.swapBuffers()
    pollEvents()
