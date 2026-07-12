import { Routes, Route } from "react-router-dom";
import { Signup } from "./pages/auth/Signup";

function App() {
  return (
    <Routes>
      <Route path="/signup" element={<Signup />} />
    </Routes>
  );
}

export default App;
