import unittest
from fastapi.testclient import TestClient
from backend.app.main import app


class TestAPIEndpoints(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def test_health_endpoint(self):
        with TestClient(app) as client:
            response = client.get("/api/v1/health")
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertEqual(data["status"], "ok")
            self.assertGreater(data["total_courses"], 40)
            self.assertGreater(data["total_chunks"], 100)

    def test_courses_list_endpoint(self):
        with TestClient(app) as client:
            response = client.get("/api/v1/courses")
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertIn("courses", data)
            self.assertGreater(data["total"], 40)

    def test_course_detail_endpoint(self):
        with TestClient(app) as client:
            response = client.get("/api/v1/courses/PRM393")
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertEqual(data["code"], "PRM393")
            self.assertEqual(data["credits"], 3)

    def test_course_detail_not_found(self):
        with TestClient(app) as client:
            response = client.get("/api/v1/courses/NON_EXISTENT_999")
            self.assertEqual(response.status_code, 404)

    def test_chat_endpoint_success(self):
        with TestClient(app) as client:
            payload = {"question": "Môn PRM393 có mấy tín chỉ?"}
            response = client.post("/api/v1/chat", json=payload)
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertIn("answer", data)
            self.assertIn("sources", data)
            self.assertIn("3", data["answer"])

    def test_chat_endpoint_with_prompt_alias(self):
        """Tests that Flutter payload {'prompt': '...'} works identically."""
        with TestClient(app) as client:
            payload = {"prompt": "Hình thức thi môn PRM393"}
            response = client.post("/api/v1/chat", json=payload)
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertIn("answer", data)

    def test_chat_endpoint_empty_question(self):
        with TestClient(app) as client:
            payload = {"question": ""}
            response = client.post("/api/v1/chat", json=payload)
            self.assertEqual(response.status_code, 400)


if __name__ == "__main__":
    unittest.main()
