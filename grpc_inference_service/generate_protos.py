import sys
import os
import subprocess

def compile_proto():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    proto_dir = os.path.join(script_dir, "protos")
    proto_file = os.path.join(proto_dir, "chat_inference.proto")

    if not os.path.exists(proto_file):
        print(f"Error: {proto_file} not found!")
        return False

    cmd = [
        sys.executable,
        "-m",
        "grpc_tools.protoc",
        f"-I{proto_dir}",
        f"--python_out={script_dir}",
        f"--grpc_python_out={script_dir}",
        proto_file
    ]

    print(f"Compiling protobuf: {' '.join(cmd)}")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Compilation failed:\nSTDOUT: {res.stdout}\nSTDERR: {res.stderr}")
        return False

    print("Successfully generated chat_inference_pb2.py and chat_inference_pb2_grpc.py!")
    return True

if __name__ == "__main__":
    compile_proto()
