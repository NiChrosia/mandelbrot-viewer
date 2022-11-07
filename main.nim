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
#version 330

uniform vec2 resolution;

uniform vec2 zCenter;
uniform float zSize;

uniform int iterations;

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
vec2 f(vec2 z, vec2 c) {
    float r = z.x * z.x - z.y * z.y;
    float i = z.x * z.y + z.x * z.y;

    vec2 squared = vec2(r, i);
    return squared + c;
}

void main() {
    vec2 uv = gl_FragCoord.xy / resolution;
    // center + (uv converted to -2 .. 2) * (zoom factor (smaller is more zoomed in) / 4)
    vec2 c = zCenter + (uv * 4.0 - vec2(2.0)) * (zSize / 4.0);

    vec2 z = vec2(0.0, 0.0);
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

    gl_FragColor = escaped ? vec4(palette(float(iterations - passed) / float(iterations), a, b, pc, d), 1.0) : vec4(vec3(0.0), 1.0);
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

glUniform2f(l("resolution"), window.size.x.float32, window.size.y.float32)

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

var zCenter = [0f, 0f]
var zSize = 3f
var iterations: int32 = 1000

proc input =
    if window.buttonDown[KeyA]:
        zCenter[0] -= zSize / 10f
    if window.buttonDown[KeyD]:
        zCenter[0] += zSize / 10f
    if window.buttonDown[KeyW]:
        zCenter[1] += zSize / 10f
    if window.buttonDown[KeyS]:
        zCenter[1] -= zSize / 10f

    if window.buttonDown[KeyMinus]:
        if iterations > 50:
            iterations -= 10
    
    if window.buttonDown[KeyEqual]:
        if iterations < 10000:
            iterations += 10

    zSize *= 1f + window.scrollDelta.y * 0.1f

window.onFrame = proc =
    glClearColor(0f, 0f, 0f, 0f)
    glClear(GL_COLOR_BUFFER_BIT)

    glUniform2f(l("zCenter"), zCenter[0], zCenter[1])
    glUniform1f(l("zSize"), zSize)
    glUniform1i(l("iterations"), iterations)

    glDrawArrays(GL_TRIANGLES, 0, 6)

while not window.closeRequested:
    input()

    window.swapBuffers()
    pollEvents()